module LogSearcher
  KEY = "logSrch#{Rails.env.test? ? ":test" : ""}:".freeze
  DEFAULT_LOG_PATH = (ENV["LOG_SEARCH_PATH"] || "#{Rails.root}/log/#{Rails.env}.log").freeze
  SEARCHES_MATCHES = %w[BikesController#index
    Organized::BikesController#index
    Admin::BikesController#index
    API::V1::BikesController#index
    API::V1::BikesController#stolen_ids
    api/v2/bikes_search
    api/v3/search
  ].freeze

  class << self
    def searches_regex
      SEARCHES_MATCHES.reject { |s| s.match?(/.BikesController#index/) }.join("|")
    end

    def time_regex(time)
    end

    # If a time is passed, it only returns lines that occurred within that hour
    def rgrep_command(time = nil, log_path: nil)
      log_path ||= DEFAULT_LOG_PATH
      "rg '#{searches_regex}' '#{log_path}'" + time_rgrep(time)
    end

    def matching_search_lines(time = nil, log_path: nil)
      `#{rgrep_arguments(time, log_path: log_path)}`
    end

    # This is for diagnostics, to count how many are returned
    # Probably won't include forever
    def rgrep_command_log_lines(command)
      `#{command}" | wc -l`.strip.to_i
    end

    def write_log_lines(log_lines)
      redis { |r| r.lpush(KEY, log_lines) }
    end

    def get_log_line
      redis { |r| r.rpop(KEY) }
    end

    def log_lines_in_redis
      redis { |r| r.llen(KEY) }
    end

    private

    def time_rgrep(time)
      return "" if time.blank?
      " | rg '\AI,\s\[#{time.utc.strftime('%Y-%m-%dT%H')}'"
    end

    # Should be the canonical way of using redis
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
