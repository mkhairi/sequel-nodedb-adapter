require "sequel"
require "json"
require "nodedb"

# Sequel adapter for NodeDB.
#
# Usage in database.yml / connection string:
#   DB = Sequel.connect("nodedb://nodedb:password@localhost:6432/mydb")
#
# Or explicitly:
#   DB = Sequel.connect(
#     adapter:  :nodedb,
#     host:     "localhost",
#     port:     6432,
#     database: "mydb",
#     user:     "nodedb",
#     password: "secret"
#   )
#
# NodeDB-specific SQL builders are available via NodeDB::SQL::*.
# Type mapping is available via NodeDB::TypeMap.resolve(nodedb_type).
#
# Dataset CRUD, schema introspection, NodeDB DDL helpers
# (create_collection / create_vector_index), and engine helpers
# (search_vector / graph_stats) work. Sequel model plugins and TypeMap
# casting of result values are roadmap.
module Sequel
  module Adapters
    module NodeDB
      # Sequel::Database subclass for NodeDB.
      # Delegates connection to NodeDB::Connection (PG::Connection, port 6432).
      class Database < Sequel::Database
        set_adapter_scheme :nodedb

        def connect(server)
          opts = server_opts(server)
          ::NodeDB::Connection.connect(
            host:     opts[:host]     || "localhost",
            port:     (opts[:port]    || ::NodeDB::Connection::DEFAULT_PORT).to_i,
            dbname:   opts[:database] || opts[:dbname],
            user:     opts[:user]     || opts[:username],
            password: opts[:password].to_s
          )
        end

        def disconnect_connection(conn)
          conn.close
        end

        def execute(sql, opts = OPTS)
          synchronize(opts[:server]) do |conn|
            result = conn.exec(sql)
            yield result if block_given?
            result
          rescue PG::Error => e
            raise ::NodeDB::QueryError, e.message
          end
        end

        # Wire our Dataset subclass in — without this Sequel hands out
        # bare Sequel::Dataset instances, which have no fetch_rows and
        # crash on the first query.
        def dataset_class_default
          Dataset
        end

        # NodeDB uses DESCRIBE instead of information_schema.columns.
        # DESCRIBE can emit a duplicate built-in `id` row on
        # document_strict collections (upstream BUG-007) — dedupe.
        def schema_parse_table(table_name, _opts = {})
          rows = execute(::NodeDB::SQL::Collection.describe(table_name.to_s))
          rows.reject { |r| r["field"].to_s.start_with?("__") }
              .uniq { |r| r["field"].to_s }
              .map do |r|
            pg_type, _oid = ::NodeDB::TypeMap.resolve(r["type"].to_s)
            nullable = r["nullable"].to_s == "true"
            [r["field"].to_sym, { db_type: pg_type, allow_null: nullable, primary_key: false, default: nil }]
          end
        end

        # NodeDB has no schemas; return the table name unchanged.
        def literal_identifier(v)
          v.to_s
        end

        # ---- NodeDB DDL helpers -------------------------------------

        # Create a NodeDB collection.
        #
        #   DB.create_collection(:articles)                      # schemaless document
        #   DB.create_collection(:metrics, engine: :timeseries,
        #     engine_options: { retention: "7d" })
        #   DB.create_collection(:audit, engine: :document_strict,
        #     columns: ["id TEXT PRIMARY KEY", "actor TEXT"],
        #     bitemporal: true)
        def create_collection(name, engine: nil, columns: [], engine_options: {}, bitemporal: false)
          execute(::NodeDB::SQL::Collection.create(
            name.to_s, engine: engine, columns: columns,
            engine_options: engine_options,
            flags: bitemporal ? [:bitemporal] : []
          ))
        end

        def drop_collection(name, if_exists: false)
          sql = if if_exists
                  ::NodeDB::SQL::Collection.drop_if_exists(name.to_s)
                else
                  ::NodeDB::SQL::Collection.drop(name.to_s)
                end
          execute(sql)
        end

        # Collection names as an Array of Strings.
        def collections
          execute(::NodeDB::SQL::Collection.show).map { |r| r["name"] }
        end

        def create_vector_index(index_name, on:, column:, metric: :cosine, dim:)
          execute("CREATE VECTOR INDEX #{index_name} ON #{on} " \
                  "METRIC #{metric.to_s.upcase} DIM #{dim.to_i}")
        end

        def drop_vector_index(index_name)
          execute("DROP VECTOR INDEX #{index_name}")
        rescue ::NodeDB::QueryError => e
          raise unless e.message.include?("does not exist")
        end

        # ---- NodeDB engine helpers ----------------------------------

        # Nearest-neighbour search. Returns Array of
        # { "surrogate" => ..., "distance" => ... } hashes — SEARCH does
        # not project document fields.
        def search_vector(table, column, embedding, limit: 10, filter: nil)
          result = execute(::NodeDB::SQL::Vector.search(
            table: table.to_s, column: column.to_s,
            embedding: embedding, limit: limit, filter: filter
          ))
          result.map do |row|
            parsed = JSON.parse(row["result"])
            { "surrogate" => parsed["_surrogate"], "distance" => parsed["distance"] }
          end
        end

        # Persistent O(1) graph edge-store counters. Pass the bare
        # collection name; omit for the tenant-wide form.
        def graph_stats(collection: nil, verbose: false, as_of: nil)
          scoped = collection && "'#{collection.to_s.gsub("'", "''")}'"
          execute(::NodeDB::SQL::Graph.stats(
            collection: scoped, verbose: verbose, as_of: as_of
          )).to_a
        end
      end

      # Sequel::Dataset subclass — minimal pass-through.
      # Executes SQL strings against the NodeDB connection.
      class Dataset < Sequel::Dataset
        def fetch_rows(sql)
          execute(sql) do |result|
            self.columns = result.fields.map(&:to_sym) if result.respond_to?(:fields)
            result.each { |row| yield row.transform_keys(&:to_sym) }
          end
          self
        end

        # NodeDB stores identifiers as written — the base Dataset's
        # SQL-standard :upcase folding would turn every query into
        # SELECT ID FROM TBL and match nothing.
        def input_identifier(v)
          v.to_s
        end

        # NodeDB silently matches zero rows for table-qualified column
        # refs (BUG-025) and rejects quoted identifiers in several
        # engine clauses — emit bare identifiers everywhere.
        def quoted_identifier_append(sql, name)
          sql << name.to_s
        end
      end
    end
  end
end
