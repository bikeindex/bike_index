# frozen_string_literal: true

module TimeZoneParser
  class << self
    def parse(time_zone_str)
      return nil if time_zone_str.blank?
      return time_zone_str if time_zone_str.is_a?(ActiveSupport::TimeZone) # in case we were given a time_zone obj

      # tzinfo requires non-whitespaced strings, so try that if the normal lookup fails
      ActiveSupport::TimeZone[time_zone_str] ||
        ActiveSupport::TimeZone[time_zone_str.to_s.strip.tr("\s", "_")]
    end

    def parse_from_time_string(time_str)
      return unless time_str.present? && time_string_has_zone_info?(time_str)

      at = Time.parse(time_str.to_s)
      offset_seconds = at.utc_offset
      # Otherwise this returns casablanca. Guess UTC over London
      return ActiveSupport::TimeZone["UTC"] if offset_seconds == 0

      prioritized_zones_matching_offset(at, offset_seconds).first
    end

    def parse_from_time_and_offset(time:, offset:)
      offset_seconds = offset.is_a?(String) ? Time.zone_offset(offset) : offset
      offset_seconds ||= offset.to_i # Fallback parsing of seconds in a string

      prioritized_zones_matching_offset(time, offset_seconds).first
    end

    def full_name(time_zone)
      # TODO: figure out an easier way to get this
      ActiveSupport::TimeZone::MAPPING.key(time_zone.tzinfo.name) || time_zone.name
    end

    private

    # TODO: This might be overly complicated garbage
    def time_string_has_zone_info?(time_str)
      return false if TimeParser.looks_like_timestamp?(time_str)
      timezone_patterns = [
        /[+-]\d{2}:?\d{2}\b/,          # +0900, +09:00, -0500, etc
        /\b(?:UTC|GMT)\b/i,            # UTC or GMT
        /\b[A-Z]{3,4}\b/,              # EST, PDT, AEST, etc
        /[+-]\d{4}\b/,                 # +0900, -0500 without colon
        /Z\b/,                         # UTC (Zulu time)
        /\[[-+A-Za-z0-9\/]+\]/         # Time zone in brackets [America/New_York]
      ]

      # Try parsing to validate it's actually a time string
      Time.parse(time_str)

      # Check if any timezone pattern matches
      timezone_patterns.any? { |pattern| time_str.match?(pattern) }
    rescue ArgumentError
      false
    end

    # Guess possible time zones based on UTC offset at a specific time
    # Returns an array of [timezone_name, city_name] pairs
    def prioritized_zones_matching_offset(at, offset_seconds)
      # Convert seconds to hours for comparison
      offset_hours = offset_seconds / 3600.0

      # Get all time zones
      possible_zones = ActiveSupport::TimeZone.all.select do |zone|
        # Calculate the offset at the specific time
        zone_time = at.in_time_zone(zone)
        zone_offset = zone_time.utc_offset / 3600.0

        zone_offset == offset_hours
      end

      # Sort zones by priority/popularity
      prioritize_zones(possible_zones)
    end

    def prioritize_zones(zones)
      zones.sort_by do |zone|
        priority = case zone.tzinfo.name
        # Major US zones
        when /New_York/, /Chicago/, /Los_Angeles/ then 1
        # Major European zones
        when /London/, /Paris/, /Berlin/ then 5
        # Major Asian zones
        when /Tokyo/, /Shanghai/, /Singapore/ then 5

        # Major cities generally
        when /Mexico City|Sydney|Hong_Kong|Dubai|Toronto|Vancouver/ then 10
        # State/Provincial capitals
        when /Melbourne|Brisbane|Perth|Montreal|Edmonton/ then 20
        # Smaller cities
        else 100
        end

        [priority, zone]
      end
    end
  end
end
