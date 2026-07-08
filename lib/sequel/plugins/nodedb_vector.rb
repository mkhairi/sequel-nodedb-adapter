module Sequel
  module Plugins
    # Vector-search sugar for models over collections with a vector index.
    #
    #   class Article < Sequel::Model
    #     plugin :nodedb_vector
    #     vector_column :embedding, dim: 384
    #   end
    #
    #   Article.search_vector(:embedding, query_vec, limit: 10)
    module NodedbVector
      module ClassMethods
        def vector_columns
          @vector_columns ||= {}
        end

        def vector_column(name, dim:, metric: :cosine)
          vector_columns[name.to_sym] = { dim: dim, metric: metric }
        end

        # Array of { "id" => ..., "surrogate" => ..., "distance" => ... }.
        # Delegates to Database#search_vector.
        def search_vector(column, embedding, limit: 10, filter: nil)
          db.search_vector(table_name, column, embedding, limit: limit, filter: filter)
        end
      end
    end
  end
end
