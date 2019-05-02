class ScheduledWorker
  include Sidekiq::Worker
  sidekiq_options queue: "low_priority", backtrace: true, retry: false

  def self.frequency
    30.seconds
  end

  def self.queue_maximum_addition_size
    200
  end

  def self.last_finished
    ScheduledWorkerRunner.worker_history(name, "last_finished")
  end

  def self.last_started
    ScheduledWorkerRunner.worker_history(name, "last_started")
  end

  def self.write_history(record)
    ScheduledWorkerRunner.write_worker_history(name, record)
  end

  def self.redis_queue
    "queue:#{sidekiq_options["queue"]}".freeze
  end

  def self.enqueued?
    # Check sidekiq's redis - which may be distinct from other redis things
    Sidekiq.redis do |conn|
      # Don't try to find the job if the queue is over max size
      return true if conn.llen(redis_queue) > queue_maximum_addition_size
      # Jobs are json encoded in redis. Grab all of them and just match them by string
      conn.lrange(redis_queue, 0, -1).any? { |job| job.match(/class...#{name}/).present? }
    end
  end

  def self.should_enqueue?
    return false if enqueued?
    last_started.blank? || Time.parse(last_started) + frequency < Time.now
  end

  # Should be the new cannonical way of using redis
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

  def record_scheduler_started
    self.class.write_history("last_started")
  end

  def record_scheduler_finished
    self.class.write_history("last_finished")
  end
end
