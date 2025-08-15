class LogSearcher::Reader
  KEY = "logSrch#{Rails.env.test? ? ":test" : ""}:".freeze
  DEFAULT_LOG_PATH = (ENV["LOG_SEARCH_PATH"] || "#{Rails.root}/log/#{Rails.env}.log").freeze
  SEARCHES_MATCHES = %w[api/v2/bikes_search
    api/v2/bikes/check_if_registered
    api/v3/search
    api/v3/bikes/check_if_registered
    API::V1::BikesController#index
    API::V1::BikesController#stolen_ids
    API::V1::BikesController#close_serial
    Organized::BikesController#index
    Admin::BikesController#index
    OrgPublic::ImpoundedBikesController#index
    Organized::ImpoundRecordsController#index
    ParkingNotificationsController#index
    Search::].freeze

  class << self
    # Remove search matches that contain bikesController index (which are already matched)
    # Including them for clarity/documentation
    def searches_regex
      SEARCHES_MATCHES.reject { |s| s.match?(/.BikesController#index/) }.join("|")
    end

    # If a time is included, it returns lines that occurred in the hour of the time
    # If no time is included, it returns all the lines from the file
    def rgrep_command_str(time = nil, log_path: nil)
      log_path ||= DEFAULT_LOG_PATH
      "rg '#{searches_regex}' '#{log_path}'" + time_rgrep(time) + " | sort -u"
    end

    # This is for diagnostics, to count how many are returned
    def rgrep_log_lines_count(time = nil, log_path: nil, rgrep_command: nil)
      rgrep_command ||= rgrep_command_str(time, log_path: log_path)
      `#{rgrep_command} | wc -l`.strip.to_i
    end

    def write_log_lines(time = nil, log_path: nil, rgrep_command: nil)
      rgrep_command ||= rgrep_command_str(time, log_path: log_path)
      RedisPool.conn do |r|
        r.pipelined do |pipeline|
          IO.popen(rgrep_command) { |io| io.each { |l| pipeline.lpush(KEY, l) } }
        end
      end
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
      " | rg '\\AI,\\s\\[#{time.utc.strftime("%Y-%m-%dT%H")}'"
    end
  end
end
