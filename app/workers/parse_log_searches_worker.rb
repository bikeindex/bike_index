class ParseLogSearchesWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  class << self
    def frequency
      1.minute
    end

    def parse_log_line(log_line)
      raise "Multiple line_data matches for log line #{log_line}" if log_line.match?(/\] \{.*\] \{/)
      line_data, opts = log_line.split("] {")
      opts = JSON.parse("{#{opts}")
      page = opts.dig("params", "page")
      {
        request_at: parse_request_time(line_data),
        request_id: line_data.split("[").last,
        duration_ms: opts["duration"]&.to_f.round,
        user_id: opts["u_id"],
        organization_id: Organization.friendly_find_id(opts.dig("params", "organization_id")),
        endpoint: parse_endpoint(opts),
        ip_address: opts["remote_ip"],
        query_items: opts["params"].except("organization_id", "page"),
        page: [nil, "1"].include?(page) ? nil : page.to_i
      }
    end

    private

    def parse_request_time(line_data)
      time_str = line_data.gsub("I, [", "").split(" #").first
      Time.parse("#{time_str} UTC")
    end

    def parse_endpoint(opts)
      :web
    end
  end

  def perform
  end
end
