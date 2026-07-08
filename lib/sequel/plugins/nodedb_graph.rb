require "json"

module Sequel
  module Plugins
    # Graph operations for models over collections that also act as a
    # graph (nodes + edges share the collection).
    #
    #   class SocialNode < Sequel::Model
    #     plugin :nodedb_graph
    #   end
    #
    #   SocialNode.graph_insert_edge(from: "alice", to: "bob", type: "knows")
    #   SocialNode.graph_traverse(from: "alice", depth: 2)
    #   SocialNode.graph_stats
    #
    # Note: libpq prints harmless "could not interpret result from
    # server: INSERT EDGE / GRAPH ..." lines to stderr for NodeDB's
    # custom command tags; the statements succeed regardless.
    module NodedbGraph
      module ClassMethods
        def graph_insert_edge(from:, to:, type:, properties: {})
          db.execute(::NodeDB::SQL::Graph.insert_edge(
            in_collection:   table_name.to_s,
            from:            db.literal(from.to_s),
            to:              db.literal(to.to_s),
            type:            db.literal(type.to_s),
            properties_json: db.literal(properties.to_json)
          ))
        end

        # Node ID strings reachable from `from` within `depth` hops,
        # excluding the starting node. Handles both traverse payload
        # shapes (flat ID array; {nodes:, edges:} object).
        def graph_traverse(from:, depth: 1, direction: :both)
          rows = db.execute(::NodeDB::SQL::Graph.traverse(
            from:      db.literal(from.to_s),
            depth:     depth,
            direction: direction
          )).to_a
          payload = JSON.parse(rows.first&.fetch("result", "[]") || "[]")

          ids =
            case payload
            when Array then payload
            when Hash  then Array(payload["nodes"]).map { |n| n["id"] }.compact
            else            []
            end

          ids - [from.to_s]
        end

        def graph_algo(algo, **options)
          db.execute(::NodeDB::SQL::Graph.algo(
            table: table_name.to_s, algo: algo, **options
          )).to_a
        end

        def graph_delete_edge(from:, to:, type:)
          db.execute(::NodeDB::SQL::Graph.delete_edge(
            in_collection: table_name.to_s,
            from:          db.literal(from.to_s),
            to:            db.literal(to.to_s),
            type:          db.literal(type.to_s)
          ))
        end

        # Scoped SHOW GRAPH STATS rows for this model's collection.
        def graph_stats(verbose: false, as_of: nil)
          db.graph_stats(collection: table_name.to_s, verbose: verbose, as_of: as_of)
        end
      end
    end
  end
end
