require "sequel"
require "sequel/extensions/migration"

# Makes Sequel's TimestampMigrator work against NodeDB.
#
# Usage:
#   require "sequel/adapters/nodedb/migrator_support"
#   Sequel::Adapters::NodeDB::TimestampMigrator.run(db, "db/migrate")
#
# Only the TimestampMigrator (filename-based versions, e.g.
# 20260711120000_create_articles.rb) is supported. IntegerMigrator
# (schema_info, single-row UPDATE) is not — see the spike notes in the
# feat/migrator-version-tracking PR body for why it was left out.
module Sequel
  module Adapters
    module NodeDB
      # Spike findings (against live NodeDB, 2026-07-12, sequel 5.106.0)
      # that force this to be a subclass rather than a stock
      # Sequel::Migrator.run(db, dir) call:
      #
      # 1. Sequel::Database#table_exists? rescues Sequel::DatabaseError to
      #    report a missing table as `false`. NodeDB's adapter raises
      #    NodeDB::QueryError (ERROR: table not found: ...) for a SELECT
      #    against a nonexistent collection — that's not a
      #    Sequel::DatabaseError subclass, so the stock #table_exists?
      #    lets it propagate instead of returning false. TimestampMigrator's
      #    private #schema_dataset calls db.table_exists?(table) directly,
      #    so the stock migrator can't even detect "ledger doesn't exist
      #    yet" without crashing.
      #
      # 2. TimestampMigrator#schema_dataset also calls
      #    `ds.columns.include?(column)` to verify an existing ledger has
      #    the expected column. Dataset#columns runs
      #    `SELECT * FROM <table> LIMIT 0` and reads the result's field
      #    names. NodeDB collapses the column descriptor of *any* zero-row
      #    SELECT * (LIMIT 0, or a plain SELECT * against an empty
      #    collection) to a single placeholder field named "result" instead
      #    of the real columns. A freshly created, still-empty ledger table
      #    therefore always reports `["result"]` from Dataset#columns,
      #    never the real `["id"]` — so the stock column check would
      #    always fail with "Migrator table ... does not contain column
      #    ...", even right after the ledger was created correctly.
      #
      # Neither of these is fixable by table/column name mapping alone, and
      # fixing them at the Database/Dataset level (e.g. making
      # Dataset#columns always DESCRIBE instead of probing) would change
      # column-introspection behavior for the whole adapter, well beyond
      # migrator support. Overriding only the two private methods that hit
      # these quirks — in a real subclass, not a monkey-patch of
      # Sequel::Migrator/TimestampMigrator — is the smallest viable seam.
      #
      # Ledger shape ports the activerecord-nodedb-adapter pattern
      # (lib/active_record/connection_adapters/nodedb/schema_migration.rb):
      # the version value (here, the migration filename) lives in NodeDB's
      # mandatory `id` column. Declaring a second PRIMARY KEY column (e.g.
      # `filename TEXT PRIMARY KEY`) collides with NodeDB's duplicate-empty-id
      # quirk on the second INSERT — the AR file's comment has the full
      # rationale.
      class TimestampMigrator < Sequel::TimestampMigrator
        # Deliberately not :schema_migrations — the
        # activerecord-nodedb-adapter's own SchemaMigration ledger already
        # uses that collection name against the same shared `nodedb`
        # database (per the workspace's live-daemon test convention).
        DEFAULT_TABLE = :sequel_schema_migrations

        private

        # AR-style: the version (migration filename) lives in the
        # NodeDB-mandatory `id` column, not a natural `filename` column.
        def default_schema_column
          :id
        end

        def default_schema_table
          DEFAULT_TABLE
        end

        # Overrides Sequel::TimestampMigrator#schema_dataset. Replaces the
        # two calls documented above (db.table_exists?, ds.columns) with
        # NodeDB-safe equivalents: Database#collections for existence
        # (mirrors the AR adapter) and Database#schema (DESCRIBE-based,
        # unaffected by the LIMIT 0 quirk) for the column check.
        def schema_dataset
          c = column
          ds = db.from(table)
          if db.collections.include?(table.to_s)
            cols = db.schema(table).map(&:first)
            unless cols.include?(c)
              raise(Sequel::Migrator::Error, "Migrator table #{table} does not contain column #{c}")
            end
          else
            db.create_collection(table.to_s, engine: :document_strict, columns: ["#{c} TEXT PRIMARY KEY"])
          end
          ds
        end
      end
    end
  end
end
