# frozen_string_literal: true

class TimeParser
  DEFAULT_TIMEZONE = ActiveSupport::TimeZone["America/Los_Angeles"].freeze

  def self.parse(time_str = nil, timezone_str = nil)
    return nil unless time_str.present?
    return time_str if time_str.is_a?(Time)
    if time_str.is_a?(Integer) || time_str.to_s.strip.match(/^\d+\z/) # it's only numbers, so it's a timestamp
      Time.at(time_str.to_i)
    else
      Time.zone = parse_timezone(timezone_str)
      time = Time.zone.parse(time_str.to_s)
      Time.zone = DEFAULT_TIMEZONE
      time
    end
  rescue ArgumentError => e
    # Try to parse some other, unexpected formats -
    ie11_formatted = %r{(?<month>\d+)/(?<day>\d+)/(?<year>\d+)}.match(time_str)
    just_date = %r{(?<year>\d{4})[^\d](?<month>\d\d?)}.match(time_str)
    just_date_backward = %r{(?<month>\d\d?)[^\d](?<year>\d{4})}.match(time_str)
    raise e unless ie11_formatted || just_date || just_date_backward

    # Get the successful matching regex group, and then reformat it in an expected way
    regex_match = [ie11_formatted, just_date, just_date_backward].compact.first
    new_str = %w[year month day]
      .map { |component| regex_match[component] if regex_match.names.include?(component) }
      .compact
      .join("-")

    # Add the day, if there isn't one
    new_str += "-01" unless regex_match.names.include?("day")
    # Run it through TimeParser again
    parse(new_str, timezone_str)
  end

  def self.parse_timezone(timezone_str)
    return DEFAULT_TIMEZONE unless timezone_str.present?
    return timezone_str if timezone_str.is_a?(ActiveSupport::TimeZone) # in case we were given a timezone obj
    # tzinfo requires non-whitespaced strings, so try that if the normal lookup fails
    ActiveSupport::TimeZone[timezone_str] || ActiveSupport::TimeZone[timezone_str.strip.tr("\s", "_")]
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
