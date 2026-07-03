require "spec_helper"

RSpec.describe "Sequel NodeDB adapter", :integration do
  let(:db)   { NodedbSequelHelper.db }
  let(:name) { "seq_spec_#{SecureRandom.hex(4)}" }

  after { db.drop_collection(name, if_exists: true) rescue nil }

  it "connects via a nodedb:// URL string" do
    expect(db["SELECT 1+1 AS r"].first).to eq(r: "2")
  end

  it "emits bare unqualified identifiers (NodeDB requirement)" do
    sql = db[:tbl].select(:id).where(name: "x").sql
    expect(sql).to eq(%q{SELECT id FROM tbl WHERE (name = 'x')})
  end

  describe "Dataset CRUD on document_strict" do
    before do
      db.create_collection(name, engine: :document_strict,
        columns: ["id TEXT PRIMARY KEY", "label TEXT", "score FLOAT"])
      db[name.to_sym].insert(id: "a", label: "alpha", score: 7.0)
      db[name.to_sym].insert(id: "b", label: "beta",  score: 3.0)
    end

    it "round-trips insert / select / where / count / update / delete" do
      ds = db[name.to_sym]
      expect(ds.select(:id, :label).order(:id).all)
        .to eq([{ id: "a", label: "alpha" }, { id: "b", label: "beta" }])
      expect(ds.where(label: "alpha").select(:id).all).to eq([{ id: "a" }])
      expect(ds.count).to eq(2)

      ds.where(id: "a").update(score: 9.0)
      expect(ds.where(id: "a").select(:score).first).to eq(score: "9.0")

      ds.where(id: "b").delete
      # Post-delete cardinality asserted via scan: NodeDB's count(*)
      # materializes a row counter on first read that DELETE never
      # decrements (upstream BUG-029), so ds.count would still say 2.
      expect(ds.select(:id).all).to eq([{ id: "a" }])
    end

    it "parses the schema via DESCRIBE without duplicate id rows" do
      expect(db.schema(name.to_sym).map(&:first)).to eq(%i[id label score])
    end
  end

  describe "DDL helpers" do
    it "create_collection / collections / drop_collection round-trip" do
      db.create_collection(name)
      expect(db.collections).to include(name)
      db.drop_collection(name)
      expect(db.collections).not_to include(name)
    end

    it "drop_collection(if_exists: true) is a no-op on a missing collection" do
      expect { db.drop_collection("nope_#{SecureRandom.hex(4)}", if_exists: true) }
        .not_to raise_error
    end
  end

  describe "engine helpers" do
    it "search_vector returns surrogate + distance rows" do
      db.create_collection(name)
      db.create_vector_index("idx_#{name}_emb", on: name, column: :embedding, metric: :cosine, dim: 3)
      db.execute("INSERT INTO #{name} (id, title, embedding) VALUES ('a1', 'x', ARRAY[0.1, 0.2, 0.3])")

      hits = db.search_vector(name, :embedding, [0.1, 0.2, 0.3], limit: 1)
      expect(hits.first).to include("surrogate", "distance")
    end

    it "graph_stats returns scoped counters" do
      db.create_collection(name, engine: :document_strict, columns: ["id TEXT PRIMARY KEY"])
      db.execute("INSERT INTO #{name} (id) VALUES ('a'), ('b')")
      db.execute("GRAPH INSERT EDGE IN #{name} FROM 'a' TO 'b' TYPE 'knows' PROPERTIES '{}'")

      row = db.graph_stats(collection: name).first
      expect(row["edge_count"].to_i).to eq(1)
      expect(row["collection"]).to eq(name)
    end
  end
end
