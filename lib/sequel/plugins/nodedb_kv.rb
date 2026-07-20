module Sequel
  module Plugins
    # KV sugar for models over KV collections. KV collections use `key`
    # as the primary key and `value` as the payload.
    #
    #   class Session < Sequel::Model
    #     plugin :nodedb_kv
    #   end
    #
    #   Session.kv_set("sess_abc", "token-xyz")
    #   Session.kv_get("sess_abc")
    #   Session.kv_delete("sess_abc")
    #
    # WARNING: Per-row TTL (the `ttl:` option) is currently broken on
    # upstream NodeDB — the UPDATE targets a nonexistent `ttl` column
    # and silently nulls `value`. Avoid `ttl:` until fixed upstream.
    module NodedbKv
      module ClassMethods
        # Returns the value for `key`, or nil if not found.
        # Delegates to Database#kv_get.
        def kv_get(key)
          db.kv_get(table_name, key)
        end

        # Inserts or updates `key` => `value`. Optionally issues a
        # `SET ttl` statement. Returns `value`. Delegates to
        # Database#kv_set.
        def kv_set(key, value, ttl: nil)
          db.kv_set(table_name, key, value, ttl: ttl)
        end

        # Deletes the row for `key`. Delegates to Database#kv_delete.
        def kv_delete(key)
          db.kv_delete(table_name, key)
        end
      end
    end
  end
end
