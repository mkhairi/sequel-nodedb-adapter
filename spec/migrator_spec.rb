require "spec_helper"
require "sequel/adapters/nodedb/migrator_support"
require "tmpdir"
require "fileutils"

RSpec.describe "Sequel::Adapters::NodeDB::TimestampMigrator", :integration do
  let(:db) { NodedbSequelHelper.db }
  let(:suffix) { SecureRandom.hex(4) }
  let(:ledger_table) { :"seq_migrator_ledger_#{suffix}" }
  let(:collection_a) { "seq_migrator_a_#{suffix}" }
  let(:collection_b) { "seq_migrator_b_#{suffix}" }
  let(:migrations_dir) { Dir.mktmpdir("seq-migrator-spec-") }

  before do
    File.write(File.join(migrations_dir, "20260711120000_create_a.rb"), <<~RUBY)
      Sequel.migration do
        up { create_collection(:#{collection_a}, engine: :document_strict, columns: ["id TEXT PRIMARY KEY"]) }
        down { drop_collection(:#{collection_a}, if_exists: true) }
      end
    RUBY

    File.write(File.join(migrations_dir, "20260711120100_create_b.rb"), <<~RUBY)
      Sequel.migration do
        up { create_collection(:#{collection_b}, engine: :document_strict, columns: ["id TEXT PRIMARY KEY"]) }
        down { drop_collection(:#{collection_b}, if_exists: true) }
      end
    RUBY
  end

  after do
    FileUtils.remove_entry(migrations_dir)
    [ledger_table, collection_a, collection_b].each do |name|
      db.drop_collection(name, if_exists: true)
    rescue
      nil
    end
  end

  def run_migrator(**opts)
    Sequel::Adapters::NodeDB::TimestampMigrator.run(db, migrations_dir, {table: ledger_table}.merge(opts))
  end

  def current?(**opts)
    Sequel::Adapters::NodeDB::TimestampMigrator.is_current?(db, migrations_dir, {table: ledger_table}.merge(opts))
  end

  it "applies pending migrations and records one ledger row per migration" do
    run_migrator
    expect(db.collections).to include(collection_a, collection_b)
    expect(db.from(ledger_table).select_order_map(:id)).to eq(
      ["20260711120000_create_a.rb", "20260711120100_create_b.rb"]
    )
  end

  it "is a no-op on a second run (ledger already current)" do
    run_migrator
    expect(current?).to eq(true)

    expect { run_migrator }.not_to raise_error
    expect(db.from(ledger_table).select_order_map(:id)).to eq(
      ["20260711120000_create_a.rb", "20260711120100_create_b.rb"]
    )
  end

  it "is not current before migrations are applied" do
    expect(current?).to eq(false)
  end

  it "rolls back to target 0: drops collections and empties the ledger" do
    run_migrator
    run_migrator(target: 0)

    expect(db.collections).not_to include(collection_a, collection_b)
    expect(db.from(ledger_table).select_order_map(:id)).to eq([])
    expect(current?(target: 0)).to eq(true)
  end
end
