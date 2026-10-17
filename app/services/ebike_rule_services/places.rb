# frozen_string_literal: true

module EbikeRuleServices
  # Where /ebike-rules has rules, by ISO 3166-2 code: the US states, with their abbreviation, and the places outside
  # the US the catalog classifies e-vehicles in. Only a US state's page checks a bike
  module Places
    extend Functionable

    EU_MEMBERS = %w[AT BE BG CY CZ DE DK EE ES FI FR GR HR HU IE IT LT LU LV MT NL PL PT RO SE SI SK].freeze
    # The catalog names classifications, not the places they're in
    REGION_NAMES = {
      "EU" => "European Union", "AU-ACT" => "Australian Capital Territory", "AU-NSW" => "New South Wales",
      "AU-NT" => "Northern Territory", "AU-QLD" => "Queensland", "AU-SA" => "South Australia", "AU-TAS" => "Tasmania",
      "AU-VIC" => "Victoria", "AU-WA" => "Western Australia", "CA-AB" => "Alberta", "CA-BC" => "British Columbia",
      "CA-MB" => "Manitoba", "CA-NB" => "New Brunswick", "CA-NL" => "Newfoundland and Labrador", "CA-NS" => "Nova Scotia",
      "CA-NT" => "Northwest Territories", "CA-NU" => "Nunavut", "CA-ON" => "Ontario", "CA-PE" => "Prince Edward Island",
      "CA-QC" => "Quebec", "CA-SK" => "Saskatchewan", "CA-YT" => "Yukon"
    }.freeze

    # The states, then the rest by name
    def all = us_states + outside_us

    def find(code)
      all.find { it[:code] == code } if code.is_a?(String)
    end

    def us?(place) = place[:abbr].present?

    # From a request's Cloudflare location headers: a US state, else a region the catalog has, else its country, or
    # for an EU member, the EU
    def from_location(location_hash)
      state = StateLaws.state_from_location(location_hash)
      return find("US-#{state[:abbr]}") if state

      iso = location_hash[:country_id] && Country.where(id: location_hash[:country_id]).pick(:iso)
      return if iso.blank?

      region = location_hash[:region_string]
      outside_us.find { it[:code].start_with?("#{iso}-") && region.present? && [it[:name], it[:code].delete_prefix("#{iso}-")].include?(region) } ||
        find(iso) || (find("EU") if EU_MEMBERS.include?(iso))
    end

    def us_states = StateLaws::STATES.map { {code: "US-#{it[:abbr]}", name: it[:name], abbr: it[:abbr]} }

    def outside_us = StateLaws.places.keys.map { {code: it, name: name(it)} }.sort_by { it[:name] }

    #
    # private below here
    #

    def name(code) = REGION_NAMES[code] || StatesAndCountries.countries.find { it[:iso] == code }&.dig(:name) || code

    conceal :name
  end
end
