class Counts
  STOREAGE_KEY = "counts_#{Rails.env}".freeze

  class << self
    def assign_for(count_key, value)
      redis { |r| r.hset STOREAGE_KEY, count_key, value }
    end

    def retrieve_for(count_key)
      redis { |r| r.hget STOREAGE_KEY, count_key }.to_i
    end

    def assign_total_bikes; assign_for("total_bikes", Bike.count) end

    def total_bikes; retrieve_for("total_bikes") end

    def assign_stolen_bikes; assign_for("stolen_bikes", Bike.stolen.count) end

    def stolen_bikes; retrieve_for("stolen_bikes") end

    def assign_recoveries
    end

    def recoveries; retrieve_for("recoveries") end

    def assign_recoveries_value
    end

    def recoveries_value; retrieve_for("recoveries_value") end
  end

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
