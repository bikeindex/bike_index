# frozen_string_literal: true

module Integrations
  module Strava
    module SegmentLocations
      extend Functionable

      def locations_for(segments)
        return {} if segments.blank?

        region_cache = {}
        country_cache = {}

        locations = segments.filter_map do |segment|
          next if segment["segment"].blank?

          region = segment.dig("segment", "state").presence
          region_cache[region] ||= find_region_abbreviation(region)

          country = segment.dig("segment", "country").presence
          country_cache[country] ||= find_country_abbreviation(country)

          segment_location(segment["segment"], region_cache.dig(region, :abbreviation),
            country_cache.dig(country, :abbreviation))
        end.compact.uniq

        regions = region_cache.values.compact.reject { |v| v[:name] == v[:abbreviation] }
          .to_h { |v| [v[:name], v[:abbreviation]] }
        countries = country_cache.values.compact.reject { |v| v[:name] == v[:abbreviation] }
          .to_h { |v| [v[:name], v[:abbreviation]] }

        {locations:, regions: regions.presence, countries: countries.presence}.compact
      end

      #
      # private below here
      #

      def segment_location(segment, region, country)
        city = segment["city"].presence&.strip

        # Remove country from the end of the city
        city = city&.gsub(/, #{country}\z/i, "")
        city = city&.gsub(/, usa\z/i, "") if country == "US"
        # Remove region from the end of the city
        city = city&.gsub(/, #{region}\z/i, "")

        {city:, region:, country:}.compact.presence
      end

      def find_region_abbreviation(raw_value)
        return if raw_value.blank?

        state = State.friendly_find(raw_value)
        if state
          {name: state.name, abbreviation: state.abbreviation}
        else
          {name: raw_value, abbreviation: raw_value}
        end
      end

      def find_country_abbreviation(raw_value)
        return if raw_value.blank?

        country = Country.friendly_find(raw_value)
        return {name: country.name, abbreviation: country.abbreviation} if country

        sac_hash = StatesAndCountries.countries.detect { |sac| sac[:self_name] == raw_value }
        if sac_hash.present?
          {name: sac_hash[:name], abbreviation: sac_hash[:iso]}
        else
          {name: raw_value, abbreviation: raw_value}
        end
      end

      conceal :segment_location, :find_region_abbreviation, :find_country_abbreviation
    end
  end
end
