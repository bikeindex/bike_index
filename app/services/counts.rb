module Counts
  extend Functionable

  STORAGE_KEY = "counts_#{Rails.env}".freeze

  COUNT_KEYS = %w[total_bikes stolen_bikes recoveries recoveries_value week_creation_chart organizations].freeze

  RECOVERY_AVERAGE_VALUE = 2103 # updated with calculated_recovery_average_value on 2026-4-11

  def assign_for(count_key, value)
    RedisPool.conn { |r| r.hset STORAGE_KEY, count_key, value }
    retrieve_for(count_key)
  end

  def retrieve_for(count_key)
    RedisPool.conn { |r| r.hget STORAGE_KEY, count_key }.to_i
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

  conceal :beginning_of_week, :calculated_recovery_average_value, :calculated_recoveries, :valued_recoveries
end
