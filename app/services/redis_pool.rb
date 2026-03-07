module RedisPool
  extend self

  def conn
    # Basically, crib what is done in sidekiq
    raise ArgumentError, "requires a block" unless block_given?

    pool.with { |conn| yield conn }
  end

  def pool
    @pool ||= ConnectionPool.new(timeout: 1, size: 2) do
      Redis.new(url: Bikeindex::Application.config.redis_default_url)
    end
  end

  private :pool
end
