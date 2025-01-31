# frozen_string_literal: true

module TimeParser
  DEFAULT_TIME_ZONE = ActiveSupport::TimeZone[Rails.application.class.config.time_zone].freeze
  EARLIEST_YEAR = 1900
  LATEST_YEAR = Time.current.year + 100

  class << self
    def parse(time_str = nil, time_zone_str = nil, in_time_zone: false)
      return nil unless time_str.present?
      return time_str if time_str.is_a?(Time)

      if looks_like_timestamp?(time_str)
        return parse("#{time_str}-01-01") if time_str.to_s.length == 4 # Looks like year, valid 8601 format
        # otherwise it's a timestamp
        time = Time.at(time_str.to_i)
      else
        time_zone = TimeZoneParser.parse(time_zone_str)
        Time.zone = time_zone
        time = Time.zone.parse(time_str.to_s) # Assign in time zone
        Time.zone = DEFAULT_TIME_ZONE
      end
      # Return in time_zone or not
      in_time_zone ? time_in_zone(time, time_str:, time_zone:, time_zone_str:) : time
    rescue ArgumentError => e
      # Try to parse some other, unexpected formats -
      paychex_formatted = %r{(?<month>\d+)/(?<day>\d+)/(?<year>\d+) (?<hour>\d\d):(?<minute>\d\d) (?<ampm>\w\w)}.match(time_str)
      ie11_formatted = %r{(?<month>\d+)/(?<day>\d+)/(?<year>\d+)}.match(time_str)
      just_date = %r{(?<year>\d{4})[^\d|\w](?<month>\d\d?)}.match(time_str)
      just_date_backward = %r{(?<month>\d\d?)[^\d|\w](?<year>\d{4})}.match(time_str)

      # Get the successful matching regex group, and then reformat it in an expected way
      regex_match = [paychex_formatted, ie11_formatted, just_date, just_date_backward].compact.first
      raise e unless regex_match.present?

      new_str = %w[year month day]
        .map { |component| regex_match[component] if regex_match.names.include?(component) }
        .compact
        .join("-")

      # If we end up with an unreasonable year, throw an error
      raise e unless new_str.split("-").first.to_i.between?(EARLIEST_YEAR, LATEST_YEAR)
      # Add the day, if there isn't one
      new_str += "-01" unless regex_match.names.include?("day")
      # If it's paychex_formatted there is an hour and minute
      if paychex_formatted.present?
        new_str += " #{regex_match["hour"]}:#{regex_match["minute"]}#{regex_match["ampm"]}"
      end
      # Run it through TimeParser again
      parse(new_str, time_zone_str, in_time_zone:)
    end

    def looks_like_timestamp?(time_str)
      time_str.is_a?(Integer) || time_str.is_a?(Float) || time_str.to_s.strip.match(/^\d+\z/) # it's only numbers
    end

    # Accepts a time object, rounds to minutes
    def round(time, unit = "minute")
      if unit == "second"
        time.change(usec: 0, sec: 0)
      else # Default is minute, nothing is built to manage anything else
        time.change(min: 0, usec: 0, sec: 0)
      end
    end

    private

    def time_in_zone(time, time_zone_str:, time_str: nil, time_zone: nil)
      time_zone ||= if time_zone_str.present?
        TimeZoneParser.parse(time_zone_str)
      elsif time_str.present?
        # If no time_zone_str was passed, try to parse it out of the time string
        TimeZoneParser.parse_from_time_string(time_str.to_s)
      end

      time.in_time_zone(time_zone || ActiveSupport::TimeZone["UTC"])
    end
  end
end
