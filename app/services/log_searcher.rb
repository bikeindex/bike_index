module LogSearcher
  KEY = "logSrch#{Rails.env.test? ? ":test" : ""}:".freeze
  DEFAULT_LOG_PATH = (ENV["LOG_SEARCH_PATH"] || "#{Rails.root}/log/#{Rails.env}.log").freeze
  SEARCHES_MATCHES = %w[api/v2/bikes_search
    api/v3/search
    API::V1::BikesController#index
    API::V1::BikesController#stolen_ids
    BikesController#index
    Organized::BikesController#index
    Admin::BikesController#index
    OrgPublic::ImpoundedBikesController#index
    ImpoundRecordsController#index
    ParkingNotificationsController#index
  ].freeze

  class << self
    # Remove search matches that contain bikesController index (which are already matched)
    # Including them for clarity/documentation
    def searches_regex
      SEARCHES_MATCHES.reject { |s| s.match?(/.BikesController#index/) }.join("|")
    end

    # If a time is included, it only returns lines that occurred in the hour of the time
    def rgrep_command(time = nil, log_path: nil)
      log_path ||= DEFAULT_LOG_PATH
      "rg '#{searches_regex}' '#{log_path}'" + time_rgrep(time)
    end

    def write_log_lines(rgrep_command)
      RedisPool.conn do |r|
        r.pipelined do |pipeline|
          IO.popen(rgrep_command) { |io| io.each { |l| pipeline.lpush(KEY, l) } }
        end
      end
    end

    # This is for diagnostics, to count how many are returned
    # Probably won't include forever
    def rgrep_command_log_lines(command)
      `#{command}" | wc -l`.strip.to_i
    end

    def get_log_line
      RedisPool.conn { |r| r.rpop(KEY) }
    end

    def log_lines_in_redis
      RedisPool.conn { |r| r.llen(KEY) }
    end

    private

    def time_rgrep(time)
      return "" if time.blank?
      " | rg '\\AI,\\s\\[#{time.utc.strftime('%Y-%m-%dT%H')}'"
    end
  end
end
