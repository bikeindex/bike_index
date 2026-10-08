# frozen_string_literal: true

module EbikeRules
  # Each state's e-bike law, from the e-vehicle classifications in Bike Book's catalog
  module StateLaws
    extend Functionable

    # The 50 states and D.C., alphabetical
    STATES = StatesAndCountries.states.reject { it[:abbr] == "PR" }.freeze
    STATE_ID = %r{\Aevc/us/([a-z]{2})/}

    # By abbreviation, empty when the catalog doesn't answer. A limit is nil where the state sets none
    def laws = parsed[:laws]

    def find(abbreviation) = laws[abbreviation]

    def state(abbreviation) = STATES.find { it[:abbr] == abbreviation&.upcase }

    # The state's name for a vehicle with these classifications, other than its e-bike law: its own, or one sharing their group
    def classification_name(abbreviation, ids)
      groups = parsed[:groups]
      shared = ids.flat_map { [it, *groups[it]] }
      parsed[:tiers][abbreviation]&.find { |_name, tier_ids| tier_ids.intersect?(shared) }&.first
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
    def parsed
      path = BikebookCatalog.manifest&.dig("vocabulary")
      records = path && Rails.cache.fetch(["bikebook_catalog/state_laws", path], expires_in: 1.week, skip_nil: true) do
        BikebookCatalog.fetch_json(path)&.dig("e_vehicle_classifications")&.then { parse(it) }
      end
      records || {laws: {}, tiers: {}, groups: {}}
    end

    def parse(records)
      states = records.filter_map { |id, record| [id[STATE_ID, 1].upcase, id, record] if id.match?(STATE_ID) }
      laws, tiers = states.partition { |_abbreviation, id, _record| id.match?(BikebookCatalog::E_BIKE_LAW) }
      {
        laws: laws.to_h { |abbreviation, id, record| [abbreviation, law(id, record)] },
        tiers: tiers.group_by(&:first).transform_values { it.map { |_, id, record| [record["name"], [id, *record["groups"]]] } },
        groups: records.filter_map { |id, record| [id, record["groups"]] if record["groups"] }.to_h
      }
    end

    def law(id, record)
      {
        id:,
        name: record["name"],
        description: record["description"],
        classes: record["groups"].to_a.filter_map { it[BikebookCatalog::US_CLASS, 1]&.to_i }.sort,
        watt_cap: record["max_power"],
        mph: record["max_speed"]&.then { UnitSystem.kilometers_to_miles(it).round },
        throttle: record["throttle"],
        restrictions: record["restrictions"],
        # link_to doesn't sanitize an href
        sources: record["sources"].to_a.grep(%r{\Ahttps?://})
      }
    end

    conceal :parsed, :parse, :law
  end
end
