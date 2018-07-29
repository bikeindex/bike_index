# frozen_string_literal: true

class TimeParser
  DEFAULT_TIMEZONE = ActiveSupport::TimeZone["Central Time (US & Canada)"].freeze

  def self.parse(time_str = nil, timezone_str = nil)
    return nil unless time_str.present?
    if time_str.is_a?(Integer) || time_str.to_s.strip.match(/^\d+\z/) # it's only numbers, so it's a timestamp
      Time.at(time_str.to_i)
    else
      Time.zone = ActiveSupport::TimeZone[timezone_str] if timezone_str.present? # Use hash lookup so if zone isn't found, no explode
      time = Time.zone.parse(time_str)
      Time.zone = DEFAULT_TIMEZONE
      time
    end
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
