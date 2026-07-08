require "spec_helper"

RSpec.describe "Sequel NodeDB model plugins", :integration do
  let(:db) { NodedbSequelHelper.db }
  let(:name) { "plugin_spec_#{SecureRandom.hex(4)}" }

  after {
    begin
      db.drop_collection(name, if_exists: true)
    rescue
      nil
    end
  }

  describe "nodedb_vector" do
    it "search_vector returns nearest neighbours for the model's collection" do
      db.create_collection(name)
      db.create_vector_index("idx_#{name}_emb", on: name, column: :embedding, metric: :cosine, dim: 3)
      db.execute("INSERT INTO #{name} (id, title, embedding) VALUES " \
                 "('a1', 'x', ARRAY[0.1, 0.2, 0.3]), ('a2', 'y', ARRAY[0.9, 0.8, 0.7])")

      model = Sequel::Model(db[name.to_sym])
      model.plugin :nodedb_vector
      model.vector_column :embedding, dim: 3

      hits = model.search_vector(:embedding, [0.1, 0.2, 0.3], limit: 1)
      expect(hits.length).to eq(1)
      expect(hits.first["distance"]).to be_within(0.01).of(0.0)
      expect(model.vector_columns).to eq(embedding: {dim: 3, metric: :cosine})
    end
  end

  describe "nodedb_graph" do
    it "inserts edges, traverses, reads stats, deletes edges" do
      db.create_collection(name, engine: :document_strict, columns: ["id TEXT PRIMARY KEY"])
      db.execute("INSERT INTO #{name} (id) VALUES ('alice'), ('bob'), ('carol')")

      model = Sequel::Model(db[name.to_sym])
      model.plugin :nodedb_graph

      model.graph_insert_edge(from: "alice", to: "bob", type: "knows")
      model.graph_insert_edge(from: "bob", to: "carol", type: "knows", properties: {since: 2020})

      expect(model.graph_traverse(from: "alice", depth: 2)).to include("bob", "carol")
      expect(model.graph_stats.first["edge_count"].to_i).to eq(2)

      model.graph_delete_edge(from: "alice", to: "bob", type: "knows")
      expect(model.graph_stats.first["edge_count"].to_i).to eq(1)
    end
  end

  describe "nodedb_timeseries" do
    it "filters with since/until_time and buckets with time_bucket" do
      db.create_collection(name, engine: :timeseries,
        columns: ["ts TIMESTAMP TIME_KEY", "host TEXT", "value FLOAT"])
      now_ms = Time.now.to_i * 1000
      db.execute("INSERT INTO #{name} (ts, host, value) VALUES " \
                 "(#{now_ms - 7_200_000}, 'web1', 1.0), (#{now_ms}, 'web1', 2.0)")

      model = Sequel::Model(db[name.to_sym])
      model.plugin :nodedb_timeseries

      recent = model.since(Time.now - 3600).all
      expect(recent.length).to eq(1)

      old = model.until_time(Time.now - 3600).all
      expect(old.length).to eq(1)

      expect(model.time_bucket("5 minutes").to_s)
        .to eq("time_bucket('5 minutes', timestamp) AS bucket")
    end
  end
end
