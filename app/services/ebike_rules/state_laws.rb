# frozen_string_literal: true

module EbikeRules
  module StateLaws
    extend Functionable

    LAWS = YAML.load_file(Rails.root.join("config/ebike_rules/state_laws.yml")).deep_symbolize_keys.freeze

    # The 50 states and D.C., alphabetical
    STATES = StatesAndCountries.states.reject { it[:abbr] == "PR" }.freeze

    def find(abbreviation) = LAWS[abbreviation&.to_sym]

    def state(abbreviation) = STATES.find { it[:abbr] == abbreviation&.upcase }

    # From a request's Cloudflare location headers
    def state_from_location(location_hash)
      return if location_hash[:country_id] != Country.united_states_id

      region = location_hash[:region_string]
      STATES.find { it[:name] == region || it[:abbr] == region }
    end
  end
end
