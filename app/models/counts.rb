class Counts
  COUNTS_KEY = "counts_#{Rails.env}".freeze

  def self.total_bikes=(count)
    redis { |r| r.hset COUNTS_KEY, "total_bikes", count}
  end

  def self.total_bikes
    redis { |r| r.hget COUNTS_KEY, "total_bikes" }.to_i
  end

  def self.stolen_bikes=(count)
    redis { |r| r.hset COUNTS_KEY, "stolen_bikes", count}
  end

  def self.stolen_bikes
    redis { |r| r.hget COUNTS_KEY, "stolen_bikes" }.to_i
  end

  def self.stolen_notes=(count)
    redis { |r| r.hset COUNTS_KEY, "stolen_notes", count}
  end

  def self.stolen_notes
    redis { |r| r.hget COUNTS_KEY, "stolen_notes" }.to_i
  end

  def self.recoveries=(count)
    redis { |r| r.hset COUNTS_KEY, "recoveries", count}
  end

  def self.recoveries
    redis { |r| r.hget COUNTS_KEY, "recoveries" }.to_i
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