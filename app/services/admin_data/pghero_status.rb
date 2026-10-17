# frozen_string_literal: true

module AdminData
  # Single-payload health snapshot from PgHero's primary database. Each metric
  # is captured independently so one failing query (e.g. a missing extension or
  # insufficient privilege) doesn't blank the whole report.
  module PgheroStatus
    extend Functionable

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
    QUERY_STATS_WINDOW = 24.hours

    def call
      enabled = safe(:query_stats_enabled?)
      base = {query_stats_enabled: enabled, **query_stats_payload(enabled)}
      METRICS.each_with_object(base) do |metric, result|
        result[metric] = safe(metric)
      end
    end

    #
    # private below here
    #

    # pghero:capture_query_stats resets pg_stat_statements every 5 minutes, so
    # only the captured history covers more than the current bucket
    def query_stats_payload(enabled)
      return {query_stats: nil, slow_queries: nil} unless enabled == true

      start_at = QUERY_STATS_WINDOW.ago
      stats = safe(:query_stats, historical: true, start_at:)
      return {query_stats: stats, slow_queries: nil} unless stats.is_a?(Array)

      {
        query_stats_since: (start_at if safe(:historical_query_stats_enabled?) == true),
        query_stats: stats.first(QUERY_STATS_LIMIT),
        slow_queries: ::PgHero.slow_queries(query_stats: stats)
      }
    end

    def safe(...)
      ::PgHero.public_send(...)
    rescue => e
      {error: e.message}
    end

    conceal :query_stats_payload, :safe
  end
end
