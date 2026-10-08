# frozen_string_literal: true

module EbikeRules
  # Each state's e-bike law, from the e-vehicle classifications in Bike Book's catalog
  module StateLaws
    extend Functionable

    # The 50 states and D.C., alphabetical
    STATES = StatesAndCountries.states.reject { it[:abbr] == "PR" }.freeze
    # A jurisdiction's whole e-bike law, rather than one class or tier of it
    E_BIKE_LAW = %r{/(electric_bicycle|bicycle|low_speed_electric_bicycle)\z}
    US_CLASS = %r{\Aevc/us/class_(\d)\z}

    # By abbreviation: the classes it names, its limits (nil where it sets none), and its restrictions in prose.
    # nil when the catalog doesn't answer
    def laws
      classifications&.filter_map do |id, record|
        abbreviation = id[%r{\Aevc/us/([a-z]{2})/}, 1]
        next unless abbreviation && id.match?(E_BIKE_LAW)

        [abbreviation.upcase, {
          id:,
          name: record["name"],
          description: record["description"],
          classes: record["groups"].to_a.filter_map { it[US_CLASS, 1]&.to_i }.sort,
          watt_cap: record["max_power"],
          mph: record["max_speed"]&.then { UnitSystem.kilometers_to_miles(it).round },
          throttle: record["throttle"],
          restrictions: record["restrictions"],
          sources: record["sources"].to_a
        }]
      end&.to_h
    end

    def find(abbreviation) = abbreviation && laws&.dig(abbreviation.upcase)

    def state(abbreviation) = STATES.find { it[:abbr] == abbreviation&.upcase }

    # The state's name for a vehicle with these classifications: its own, or one sharing their group
    def classification_name(abbreviation, ids)
      records = classifications or return
      shared = ids.flat_map { [it, *records.dig(it, "groups")] }
      records.find do |id, record|
        id.start_with?("evc/us/#{abbreviation.downcase}/") && [id, *record["groups"]].intersect?(shared)
      end&.last&.dig("name")
    end

    # From a request's Cloudflare location headers
    def state_from_location(location_hash)
      return if location_hash[:country_id] != Country.united_states_id

      region = location_hash[:region_string]
      STATES.find { it[:name] == region || it[:abbr] == region }
    end

    #
    # private below here
    #

    # The vocabulary's file name carries its digest, so a republished one is a new key
    def classifications
      path = BikebookCatalog.manifest&.dig("vocabulary") or return
      Rails.cache.fetch(["bikebook_catalog/e_vehicle_classifications", path], expires_in: 1.week, skip_nil: true) do
        BikebookCatalog.fetch_json(path)&.dig("e_vehicle_classifications")
      end
    end

    conceal :classifications
  end
end
