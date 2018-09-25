# frozen_string_literal: true

class TimeParser
  DEFAULT_TIMEZONE = ActiveSupport::TimeZone["Central Time (US & Canada)"].freeze

  def self.parse(time_str = nil, timezone_str = nil)
    return nil unless time_str.present?
    if time_str.is_a?(Integer) || time_str.to_s.strip.match(/^\d+\z/) # it's only numbers, so it's a timestamp
      Time.at(time_str.to_i)
    else
      Time.zone = parse_timezone(timezone_str)
      time = Time.zone.parse(time_str.to_s)
      Time.zone = DEFAULT_TIMEZONE
      time
    end
  end

  def self.parse_timezone(timezone_str)
    return nil unless timezone_str.present?
    # tzinfo requires non-whitespaced strings, so try that if the normal lookup fails
    ActiveSupport::TimeZone[timezone_str] || ActiveSupport::TimeZone[timezone_str.strip.gsub("\s", "_")]
  end

  # Accepts a time object, rounds to minutes
  def self.round(time, unit = "minute")
    if unit == "second"
      time.change(usec: 0, sec: 0)
    else # Default is minute, nothing is built to manage anything else
      time.change(min: 0, usec: 0, sec: 0)
    end
  end
end
