# frozen_string_literal: true

module BinxUtils
  module TimeParser
    EARLIEST_YEAR = 1900
    LATEST_YEAR = Time.now.year + 100

    class << self
      def default_time_zone
        @default_time_zone ||= ActiveSupport::TimeZone["Central Time (US & Canada)"]
      end

      def default_time_zone=(time_zone)
        @default_time_zone = time_zone.is_a?(ActiveSupport::TimeZone) ? time_zone : ActiveSupport::TimeZone[time_zone]
      end

      def parse(time_str = nil, time_zone_str = nil, in_time_zone: false)
        return nil unless time_str.present?
        return time_str if time_str.is_a?(Time)

        if looks_like_timestamp?(time_str)
          return parse("#{time_str}-01-01") if time_str.to_s.length == 4

          time = Time.at(time_str.to_i)
        else
          time_zone = BinxUtils::TimeZoneParser.parse(time_zone_str)
          Time.zone = time_zone
          time = Time.zone.parse(time_str.to_s)
          Time.zone = default_time_zone
        end
        in_time_zone ? time_in_zone(time, time_str:, time_zone:, time_zone_str:) : time
      rescue ArgumentError => e
        paychex_formatted = %r{(?<month>\d+)/(?<day>\d+)/(?<year>\d+) (?<hour>\d\d):(?<minute>\d\d) (?<ampm>\w\w)}.match(time_str)
        ie11_formatted = %r{(?<month>\d+)/(?<day>\d+)/(?<year>\d+)}.match(time_str)
        just_date = %r{(?<year>\d{4})[^\d|\w](?<month>\d\d?)}.match(time_str)
        just_date_backward = %r{(?<month>\d\d?)[^\d|\w](?<year>\d{4})}.match(time_str)

        regex_match = [paychex_formatted, ie11_formatted, just_date, just_date_backward].compact.first
        raise e unless regex_match.present?

        new_str = %w[year month day]
          .map { |component| regex_match[component] if regex_match.names.include?(component) }
          .compact
          .join("-")

        raise e unless new_str.split("-").first.to_i.between?(EARLIEST_YEAR, LATEST_YEAR)

        new_str += "-01" unless regex_match.names.include?("day")
        if paychex_formatted.present?
          new_str += " #{regex_match["hour"]}:#{regex_match["minute"]}#{regex_match["ampm"]}"
        end
        parse(new_str, time_zone_str, in_time_zone:)
      end

      def looks_like_timestamp?(time_str)
        time_str.is_a?(Integer) || time_str.is_a?(Float) || time_str.to_s.strip.match(/^\d+\z/)
      end

      def round(time, unit = "minute")
        if unit == "second"
          time.change(usec: 0, sec: 0)
        else
          time.change(min: 0, usec: 0, sec: 0)
        end
      end

      private

      def time_in_zone(time, time_zone_str:, time_str: nil, time_zone: nil)
        time_zone ||= if time_zone_str.present?
          BinxUtils::TimeZoneParser.parse(time_zone_str)
        elsif time_str.present?
          BinxUtils::TimeZoneParser.parse_from_time_string(time_str.to_s)
        end

        time.in_time_zone(time_zone || ActiveSupport::TimeZone["UTC"])
      end
    end
  end
end
