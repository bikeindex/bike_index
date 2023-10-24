module LogSearcher
  KEY = "logSrch#{Rails.env.test? ? ":test" : ""}:".freeze
  SEARCH_STRINGS = %w[BikesController#index
    Organized::BikesController#index
    Admin::BikesController#index
    API::V1::BikesController#index
    API::V1::BikesController#stolen_ids
    api/v2/bikes_search
    api/v3/search
  ].freeze

  LOG_PATH = ENV["LOG_SEARCH_PATH"].freeze

  class << self
    def grep_commands(time = nil)
      SEARCH_STRINGS.map { |s| s }
    end

    # This is for diagnostics, to check how many are returned
    def grep_command_log_lines(grep_command)
      `grep "#{grep_command}" #{LOG_PATH} | wc -l`.strip.to_i
    end

    def write_log_lines(log_lines)
      redis.lpush(KEY, log_lines)
    end

    def get_log_line
      redis.rpop(KEY)
    end

    def redis_log_length
      redis.llen(KEY)
    end

    # length is redis.llen(KEY)

    # Should be the canonical way of using Redis
    def redis
      # Basically, crib what is done in sidekiq
      raise ArgumentError, "requires a block" unless block_given?
      redis_pool.with { |conn| yield conn }
    end

    def redis_pool
      @redis_pool ||= ConnectionPool.new(timeout: 1, size: 2) { Redis.new }
    end
  end
end
