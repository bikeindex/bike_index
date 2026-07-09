# frozen_string_literal: true

module AdminData
  # Single-payload health snapshot from PgHero's primary database. Each metric
  # is captured independently so one failing query (e.g. a missing extension or
  # insufficient privilege) doesn't blank the whole report.
  class PgheroStatus
    METRICS = %i[
      database_size total_connections connection_stats
      running_queries long_running_queries blocked_queries
      index_hit_rate table_hit_rate index_usage
      unused_indexes unused_tables invalid_indexes duplicate_indexes
      sequence_danger transaction_id_danger autovacuum_danger
      relation_sizes maintenance_info replica? replication_lag
      last_stats_reset_time settings
    ].freeze

    QUERY_STATS_LIMIT = 25

    def self.call
      new.as_json
    end

    def as_json
      enabled = safe { ::PgHero.query_stats_enabled? }
      base = {
        query_stats_enabled: enabled,
        query_stats: (safe { ::PgHero.query_stats(limit: QUERY_STATS_LIMIT) } if enabled == true)
      }
      METRICS.each_with_object(base) do |metric, result|
        result[metric] = safe { ::PgHero.public_send(metric) }
      end
    end

    private

    def safe
      yield
    rescue => e
      {error: e.message}
    end
  end
end
