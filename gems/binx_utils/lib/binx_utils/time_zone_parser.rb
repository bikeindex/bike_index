# frozen_string_literal: true

module BinxUtils
  module TimeZoneParser
    class << self
      def parse(time_zone_str)
        return nil if time_zone_str.blank?
        return time_zone_str if time_zone_str.is_a?(ActiveSupport::TimeZone)

        ActiveSupport::TimeZone[time_zone_str] ||
          ActiveSupport::TimeZone[time_zone_str.to_s.strip.tr("\s", "_")]
      end

      def parse_from_time_string(time_str)
        return unless time_str.present? && time_string_has_zone_info?(time_str)

        at = Time.parse(time_str.to_s)
        offset_seconds = at.utc_offset
        return ActiveSupport::TimeZone["UTC"] if offset_seconds == 0

        prioritized_zones_matching_offset(at, offset_seconds).first
      end

      def parse_from_time_and_offset(time:, offset:)
        offset_seconds = offset.is_a?(String) ? Time.zone_offset(offset) : offset
        offset_seconds ||= offset.to_i

        prioritized_zones_matching_offset(time, offset_seconds).first
      end

      def full_name(time_zone)
        ActiveSupport::TimeZone::MAPPING.key(time_zone.tzinfo.name) || time_zone.name
      end

      private

      def time_string_has_zone_info?(time_str)
        return false if BinxUtils::TimeParser.looks_like_timestamp?(time_str)

        timezone_patterns = [
          /[+-]\d{2}:?\d{2}\b/,
          /\b(?:UTC|GMT)\b/i,
          /\b[A-Z]{3,4}\b/,
          /[+-]\d{4}\b/,
          /Z\b/,
          /\[[-+A-Za-z0-9\/]+\]/
        ]

        Time.parse(time_str)

        timezone_patterns.any? { |pattern| time_str.match?(pattern) }
      rescue ArgumentError
        false
      end

      def prioritized_zones_matching_offset(at, offset_seconds)
        offset_hours = offset_seconds / 3600.0

        possible_zones = ActiveSupport::TimeZone.all.select do |zone|
          zone_time = at.in_time_zone(zone)
          zone_offset = zone_time.utc_offset / 3600.0

          zone_offset == offset_hours
        end

        prioritize_zones(possible_zones)
      end

      def prioritize_zones(zones)
        zones.sort_by do |zone|
          priority = case zone.tzinfo.name
          when /New_York/, /Chicago/, /Los_Angeles/ then 1
          when /London/, /Paris/, /Berlin/ then 5
          when /Tokyo/, /Shanghai/, /Singapore/ then 5
          when /Mexico City|Sydney|Hong_Kong|Dubai|Toronto|Vancouver/ then 10
          when /Melbourne|Brisbane|Perth|Montreal|Edmonton/ then 20
          else 100
          end

          [priority, zone]
        end
      end
    end
  end
end
