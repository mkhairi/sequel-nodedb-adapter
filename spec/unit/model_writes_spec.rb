require "spec_helper"

RSpec.describe "Sequel::Model writes (no daemon)" do
  # A plain class, not a Struct: Struct#to_a shadows Enumerable#to_a,
  # and schema_parse_table calls #to_a on the result.
  fake_result = Class.new do
    include Enumerable

    attr_reader :cmd_tuples

    def initialize(rows, cmd_tuples)
      @rows = rows
      @cmd_tuples = cmd_tuples
    end

    def fields = @rows.first&.keys || []
    def each(&) = @rows.each(&)
  end

  let(:conn) do
    log = []
    double("pg conn", log: log, close: nil).tap do |c|
      allow(c).to receive(:exec) do |sql|
        log << sql
        case sql
        when /\ADESCRIBE/
          # DESCRIBE repeats the key column with a PRIMARY KEY type.
          # NodeDB::Schema.normalize derives primary_key from that row.
          fake_result.new([
            {"field" => "id", "type" => "TEXT", "nullable" => "false"},
            {"field" => "id", "type" => "TEXT PRIMARY KEY", "nullable" => "false"},
            {"field" => "name", "type" => "TEXT", "nullable" => "true"}
          ], 0)
        when /\ASELECT .* WHERE/ then fake_result.new([{"id" => "a2", "name" => "n"}], 1)
        when /\A(UPDATE|DELETE|INSERT)/ then fake_result.new([], 1)
        else fake_result.new([], 0)
        end
      end
    end
  end

  let(:db) do
    allow(NodeDB::Connection).to receive(:connect).and_return(conn)
    Sequel.connect(adapter: :nodedb, host: "127.0.0.1", database: "default", test: false)
  end

  let(:artist) do
    Class.new(Sequel::Model(db[:artists])).tap(&:unrestrict_primary_key)
  end

  it "returns the row count from Dataset#update" do
    expect(db[:artists].where(id: "a1").update(name: "z")).to eq(1)
  end

  it "returns the row count from Dataset#delete" do
    expect(db[:artists].where(id: "a1").delete).to eq(1)
  end

  it "saves an existing record through Model#save" do
    m = artist.load(id: "a1", name: "x")
    m.name = "y"
    expect { m.save }.not_to raise_error
    expect(conn.log.any? { |s| s.start_with?("UPDATE artists SET name = 'y'") }).to be(true)
  end

  it "destroys an existing record through Model#destroy" do
    expect { artist.load(id: "a1", name: "x").destroy }.not_to raise_error
  end

  it "creates a record with a client-set primary key" do
    rec = nil
    expect { rec = artist.create(id: "a2", name: "n") }.not_to raise_error
    expect(rec.id).to eq("a2")
  end
end
