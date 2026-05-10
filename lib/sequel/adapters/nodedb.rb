require "sequel"
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
# NOTE: This adapter is a stub. Full Sequel Dataset and Schema integration
# is pending resolution of NodeDB BUG-001 (INSERT on document collections).
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
            conn.exec(sql)
          rescue PG::Error => e
            raise ::NodeDB::QueryError, e.message
          end
        end

        # NodeDB uses DESCRIBE instead of information_schema.columns.
        def schema_parse_table(table_name, _opts = {})
          rows = execute(::NodeDB::SQL::Collection.describe(table_name.to_s))
          rows.reject { |r| r["field"].to_s.start_with?("__") }.map do |r|
            pg_type, _oid = ::NodeDB::TypeMap.resolve(r["type"].to_s)
            nullable = r["nullable"].to_s == "true"
            [r["field"].to_sym, { db_type: pg_type, allow_null: nullable, primary_key: false, default: nil }]
          end
        end

        # NodeDB has no schemas; return the table name unchanged.
        def literal_identifier(v)
          v.to_s
        end
      end

      # Sequel::Dataset subclass — minimal pass-through.
      # Executes SQL strings against the NodeDB connection.
      class Dataset < Sequel::Dataset
        def fetch_rows(sql)
          execute(sql) do |result|
            result.each { |row| yield row.transform_keys(&:to_sym) }
          end
        end
      end
    end
  end
end
