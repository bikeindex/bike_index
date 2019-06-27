class Counts
  STOREAGE_KEY = "counts_#{Rails.env}".freeze

  class << self
    def assign_for(count_key, value)
      redis { |r| r.hset STOREAGE_KEY, count_key, value }
      retrieve_for(count_key) # To be nice
    end

    def retrieve_for(count_key)
      redis { |r| r.hget STOREAGE_KEY, count_key }.to_i
    end

    def count_keys
      %w[total_bikes stolen_bikes recoveries recoveries_value week_creation_chart organizations]
    end

    def recovery_average_value
      1428 # 2019/5/20 - calculated by averaging the value of the recoveries that had listed values
    end

    def beginning_of_week
      (Time.current - 7.days).end_of_day + 1.minute
    end

    def total_bikes; retrieve_for("total_bikes") end

    def stolen_bikes; retrieve_for("stolen_bikes") end

    def organizations; retrieve_for("organizations") end

    # TODO: Dupe method definition
    def week_creation_chart; retrieve_for("week_creation_chart") end

    def week_creation_chart
      chart_data = redis { |r| r.hget STOREAGE_KEY, "week_creation_chart" }
      chart_data.present? ? JSON.parse(chart_data) : chart_data
    end

    # And here are the assignments:
    def assign_stolen_bikes; assign_for("stolen_bikes", Bike.stolen.count) end

    def assign_total_bikes; assign_for("total_bikes", Bike.count) end

    def assign_organizations; assign_for("organizations", Organization.count) end

    def assign_recoveries
      # StolenBikeRegistry.com had just over 2k recoveries prior to merging. The recoveries weren't imported, so manually calculate
      assign_for("recoveries", StolenRecord.recovered.where("date_recovered < ?", Time.current.beginning_of_day).count + 2_041)
    end

    def assign_week_creation_chart
      assign_for("week_creation_chart", Bike.unscoped.where(created_at: beginning_of_week..Time.current).group_by_day(:created_at).count.to_json)
    end

    def recoveries; retrieve_for("recoveries") end

    def assign_recoveries_value
      valued = StolenRecord.recovered.where("date_recovered < ?", Time.current.beginning_of_day).pluck(:estimated_value).reject(&:blank?)
      # Sum of the recovered bikes with estimated_values + recovery_average_value * the number of bikes without an estimated_value
      assign_for("recoveries_value", valued.sum + (recoveries - valued.count) * recovery_average_value)
    end

    def recoveries_value; retrieve_for("recoveries_value") end
  end

  # TODO: This `protected` has no effect. Do we want to move the methods below
  # into the class << self?
  protected

  # Should be the new canonical way of using redis
  def self.redis
    # Basically, crib what is done in sidekiq
    raise ArgumentError, "requires a block" unless block_given?
    redis_pool.with { |conn| yield conn }
  end

  def self.redis_pool
    @redis ||= ConnectionPool.new(timeout: 1, size: 2) do
      Redis.new
    end
  end
end
