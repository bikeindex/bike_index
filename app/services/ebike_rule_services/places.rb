# frozen_string_literal: true

module EbikeRuleServices
  # Where /ebike-rules has rules, by ISO 3166-2 code: the US states, with their abbreviation, and the places outside
  # the US the catalog classifies e-vehicles in. A US state's page checks a bike, as a Canadian province's does
  module Places
    extend Functionable

    CHECKED_COUNTRIES = %w[US CA].freeze
    # Canada's e-bike laws all stop the motor here
    CANADA_SPEED_CAP_KMH = 32
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
    COUNTRY_NAMES = StatesAndCountries.countries.to_h { [it[:iso], it[:name]] }.freeze

    def all = us_states + outside_us

    # A state's without reading the catalog
    def find(code)
      return unless code.is_a?(String)

      (code.start_with?("US-") ? us_states : outside_us).find { it[:code] == code }
    end

    def us?(place) = place[:abbr].present?

    def country(place) = place[:code].split("-").first

    # The country whose regions the page picks between: the place's where they check a bike, else the US
    def checked_country(place) = (place && CHECKED_COUNTRIES.include?(country(place))) ? country(place) : "US"

    def checks?(place) = place[:code].include?("-") && CHECKED_COUNTRIES.include?(country(place))

    def regions(country) = (country == "US") ? us_states : outside_us.select { it[:code].start_with?("#{country}-") }

    # From a request's Cloudflare location headers: a US state, else a region the catalog has, else its country, or
    # for an EU member, the EU
    def from_location(location_hash)
      state = StateLaws.state_from_location(location_hash)
      return us_state(state) if state

      iso = location_hash[:country_id] && Country.where(id: location_hash[:country_id]).pick(:iso)
      return if iso.blank?

      places = outside_us
      region = location_hash[:region_string]
      places.find { it[:code].start_with?("#{iso}-") && [it[:name], it[:code].delete_prefix("#{iso}-")].include?(region) } ||
        places.find { it[:code] == iso } || (places.find { it[:code] == "EU" } if EU_MEMBERS.include?(iso))
    end

    def us_states = StateLaws::STATES.map { us_state(it) }

    def outside_us = StateLaws.places.keys.map { {code: it, name: REGION_NAMES[it] || COUNTRY_NAMES[it] || it} }.sort_by { it[:name] }

    #
    # private below here
    #

    def us_state(state) = {code: "US-#{state[:abbr]}", name: state[:name], abbr: state[:abbr]}

    conceal :us_state
  end
end
