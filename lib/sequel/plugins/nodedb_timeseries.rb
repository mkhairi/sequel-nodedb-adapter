module Sequel
  module Plugins
    # Timeseries helpers for models over NodeDB timeseries collections.
    # NodeDB renames the TIME_KEY column to `timestamp` internally and
    # filters on epoch-millisecond integers; these wrap that away.
    #
    #   class Metric < Sequel::Model
    #     plugin :nodedb_timeseries
    #   end
    #
    #   Metric.since(Time.now - 3600).all
    #   Metric.dataset.select(Metric.time_bucket("5 minutes")).group(:bucket)
    module NodedbTimeseries
      module ClassMethods
        def since(time)
          where(Sequel.lit(::NodeDB::SQL::Timeseries.since_clause(time)))
        end

        def until_time(time)
          where(Sequel.lit(::NodeDB::SQL::Timeseries.until_clause(time)))
        end

        def time_bucket(interval, as: :bucket)
          Sequel.lit(::NodeDB::SQL::Timeseries.time_bucket(interval, as: as))
        end
      end
    end
  end
end
