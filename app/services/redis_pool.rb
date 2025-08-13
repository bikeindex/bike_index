class RedisPool
  class << self
    def conn
      # Basically, crib what is done in sidekiq
      raise ArgumentError, "requires a block" unless block_given?
      pool.with { |conn| yield conn }
    end

    private

    def pool
      @pool ||= ConnectionPool.new(timeout: 1, size: 2) do
        Redis.new(url: Bikeindex::Application.config.redis_cache_url)
      end
    end
  end
end
