module Counts
  extend Functionable

  STORAGE_KEY = "counts_#{Rails.env}".freeze

  COUNT_KEYS = %w[total_bikes stolen_bikes recoveries recoveries_value week_creation_chart logged_searches organizations].freeze

  LOGGED_SEARCH_KINDS = %w[web_bikebook web_ebike_rules organized organized_serial user user_serial web_marketplace].freeze

  RECOVERY_AVERAGE_VALUE = 2103 # updated with calculated_recovery_average_value on 2026-4-11

  def assign_for(count_key, value)
    RedisPool.conn { |r| r.hset STORAGE_KEY, count_key, value }
    retrieve_for(count_key)
  end

  def retrieve_for(count_key)
    RedisPool.conn { |r| r.hget STORAGE_KEY, count_key }.to_i
  end

  def retrieve_many(*count_keys)
    RedisPool.conn { |r| r.hmget STORAGE_KEY, *count_keys }.map(&:to_i)
  end

  def count_keys
    COUNT_KEYS
  end

  def recovery_average_value
    RECOVERY_AVERAGE_VALUE
  end

  def beginning_of_week
    (Time.current - 7.days).end_of_day + 1.minute
  end

  def total_bikes
    retrieve_for("total_bikes")
  end

  def stolen_bikes
    retrieve_for("stolen_bikes")
  end

  def organizations
    retrieve_for("organizations")
  end

  def week_creation_chart
    chart_data = RedisPool.conn { |r| r.hget STORAGE_KEY, "week_creation_chart" }
    chart_data.present? ? JSON.parse(chart_data) : chart_data
  end

  # {date => {kind => count}}, zeros for a day that hasn't been stored
  def logged_searches(dates)
    stored = RedisPool.conn { |r| r.hmget STORAGE_KEY, *dates.map { "logged_searches_#{it}" } }
    dates.zip(stored).to_h do |date, counts|
      [date, LOGGED_SEARCH_KINDS.to_h { [it, 0] }.merge(JSON.parse(counts || "{}"))]
    end
  end

  def assign_stolen_bikes
    assign_for("stolen_bikes", Bike.status_stolen.count)
  end

  def assign_total_bikes
    assign_for("total_bikes", Bike.count)
  end

  def assign_organizations
    assign_for("organizations", Organization.count)
  end

  def assign_recoveries
    # StolenBikeRegistry.com had just over 2k recoveries prior to merging. The recoveries weren't imported, so manually calculate
    assign_for("recoveries", calculated_recoveries.count + 2_041)
  end

  def assign_week_creation_chart
    assign_for("week_creation_chart", Bike.unscoped.where(created_at: beginning_of_week..Time.current).group_by_day(:created_at).count.to_json)
  end

  # Yesterday too, so the searches after the last run before midnight get counted
  def assign_logged_searches(dates = [Date.yesterday, Date.current])
    dates.each do |date|
      counts = LoggedSearch.where(request_at: date.all_day)
        .group(:endpoint, Arel.sql("serial_normalized IS NOT NULL")).count
      kind_counts = counts.group_by { |(endpoint, serial), _| logged_search_kind(endpoint, serial) }
        .except(nil).transform_values { it.sum(&:last) }
      assign_for("logged_searches_#{date}", kind_counts.to_json)
    end
  end

  def recoveries
    retrieve_for("recoveries")
  end

  def assign_recoveries_value
    # Sum of the recovered bikes with estimated_values + recovery_average_value * the number of bikes without an estimated_value
    valued = valued_recoveries
    assign_for("recoveries_value", valued.sum + (recoveries - valued.count) * recovery_average_value)
  end

  def recoveries_value
    retrieve_for("recoveries_value")
  end

  #
  # private below here
  #

  # This method isn't called in normal operation
  def calculated_recovery_average_value
    valued = valued_recoveries
    valued.sum / valued.count
  end

  def calculated_recoveries
    StolenRecord.recovered.where("recovered_at < ?", Time.current.beginning_of_day)
  end

  def valued_recoveries
    calculated_recoveries.pluck(:estimated_value).reject(&:blank?)
  end

  # The marketplace's counts lookup accompanies each of its searches, so it isn't one
  def logged_search_kind(endpoint, serial)
    case endpoint&.to_sym
    when *LoggedSearch.bikebook_endpoints, :web_marketplace then endpoint
    when :web_marketplace_count then nil
    when *LoggedSearch.organized_endpoints then serial ? "organized_serial" : "organized"
    else serial ? "user_serial" : "user"
    end
  end

  conceal :beginning_of_week, :calculated_recovery_average_value, :calculated_recoveries, :valued_recoveries,
    :logged_search_kind
end
