module Sequel
  module Plugins
    # Full-text search sugar for models over collections with a fulltext
    # index.
    #
    #   class Post < Sequel::Model
    #     plugin :nodedb_fts
    #     fts_column :body, language: "english"
    #   end
    #
    #   Post.fts_search("machine learning", limit: 20)
    #   Post.fts_search("nural networks", fuzzy: true)
    #
    # Returns an Array of Hashes with key "id". text_match() filters rows
    # server-side; look up the full record separately if you need it.
    module NodedbFts
      module ClassMethods
        def fts_columns
          @fts_columns ||= {}
        end

        def fts_column(name, language: "english")
          fts_columns[name.to_sym] = {language: language}
        end

        # Array of { "id" => ... } hashes. Delegates to Database#search_fts.
        def fts_search(query, column: fts_columns.keys.first, limit: 20, fuzzy: false)
          db.search_fts(table_name, column, query, limit: limit, fuzzy: fuzzy)
        end
      end
    end
  end
end
