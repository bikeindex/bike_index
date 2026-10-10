# frozen_string_literal: true

module EbikeRuleServices
  # Each state's e-bike law, from the e-vehicle classifications in Bike Book's catalog
  module StateLaws
    extend Functionable

    # The 50 states and D.C., alphabetical
    STATES = StatesAndCountries.states.reject { it[:abbr] == "PR" }.freeze
    STATE_ID = %r{\Aevc/us/([a-z]{2})/}
    OFF_HIGHWAY = "evc/off_highway_motorcycle"
    MOTORCYCLE = "evc/motorcycle"
    # Corrections the catalog doesn't carry yet: `either` limits are alternatives, and NOT_AN_EBIKE folds a
    # class into the one e-moto entry, listed last. New Jersey's law counts an electric motorized bicycle as
    # a motorcycle, and a dirt bike is one too
    NOT_AN_EBIKE = {id: "out_of_class", not_an_ebike: true}.freeze
    CLASS_OVERRIDES = {
      "evc/us/nj/motorized_bicycle" => {either: true},
      "evc/us/nj/electric_motorized_bicycle" => NOT_AN_EBIKE,
      "evc/us/nj/motorcycle" => NOT_AN_EBIKE,
      "evc/us/nj/dirt_bike" => NOT_AN_EBIKE
    }.freeze

    # By abbreviation, empty when the catalog doesn't answer. A limit is nil where the state sets none,
    # and a date only while it's still ahead of today
    def laws(today: Time.zone.today) = parsed[:laws].transform_values { in_force(it, today) }

    def find(abbreviation, today: Time.zone.today) = parsed[:laws][abbreviation]&.then { in_force(it, today) }

    # By abbreviation, the states whose e-bike law isn't the three US classes, each with its own classes, its law first
    def own_classes
      parsed[:classes].transform_values do |classes|
        folded, kept = classes.partition { CLASS_OVERRIDES[it[:id]] == NOT_AN_EBIKE }
        kept.map { it.merge(CLASS_OVERRIDES.fetch(it[:id], {})) } + (folded.any? ? [NOT_AN_EBIKE] : [])
      end
    end

    # nil for a state that uses the three US classes
    def classes(abbreviation) = own_classes[abbreviation]

    # The helmet, age and path rules in force for a Class 3 under the state's e-bike law
    def class_3_rules(abbreviation, today: Time.zone.today)
      find(abbreviation, today:)&.dig(:restrictions).to_a
        .select { it[:starts_on].nil? && it[:rule].match?(/\bclass 3\b/i) && it[:rule].match?(/helmet|older|\bage\b|path|trail/i) }
    end

    # The license, registration and insurance rules in force for the state's motorcycle, which an e-moto usually is
    def emoto_rules(abbreviation, today: Time.zone.today)
      parsed[:motorcycles][abbreviation].to_a
        .select { !it[:starts_on]&.>(today) && !it[:ends_on]&.<=(today) && it[:rule].match?(/licen|regist|insur/i) }
    end

    # nil for anything but an abbreviation, such as a query's array
    def state(abbreviation)
      STATES.find { it[:abbr] == abbreviation.upcase } if abbreviation.is_a?(String)
    end

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
      path = Integrations::Bikebook::Catalog.manifest&.dig("vocabulary")
      records = path && Rails.cache.fetch(["bikebook_catalog/state_laws_with_citations", path], expires_in: 1.week, skip_nil: true) do
        Integrations::Bikebook::Catalog.file(path)&.dig("e_vehicle_classifications")&.then { parse(it) }
      end
      records || {laws: {}, tiers: {}, groups: {}, classes: {}, motorcycles: {}}
    end

    def parse(records)
      states = records.filter_map { |id, record| [id[STATE_ID, 1].upcase, id, record] if id.match?(STATE_ID) }
      laws, tiers = states.partition { |_abbreviation, id, _record| id.match?(BikebookCatalog::E_BIKE_LAW) }
      # to_h keeps a state's last, so the law it goes by sorts last
      laws = laws.sort_by { |_abbreviation, id, _record| -BikebookCatalog::E_BIKE_LAWS.index(id[BikebookCatalog::E_BIKE_LAW, 1]) }
        .to_h { |abbreviation, id, record| [abbreviation, law(id, record)] }
      {
        laws:,
        tiers: tiers.group_by(&:first).transform_values { it.map { |_, id, record| [record["name"], [id, *record["groups"]]] } },
        groups: records.filter_map { |id, record| [id, record["groups"]] if record["groups"] }.to_h,
        classes: states.group_by(&:first).filter_map { |abbreviation, entries|
          law_id = laws.dig(abbreviation, :id)
          next if law_id.nil? || laws.dig(abbreviation, :classes) == [1, 2, 3]

          [abbreviation, state_classes(entries, law_id)]
        }.to_h,
        motorcycles: states.filter_map { |abbreviation, id, record|
          next unless id.end_with?("/motorcycle") || record["groups"].to_a.include?(MOTORCYCLE)

          [abbreviation, record["restrictions"].to_a.map { restriction(it) }]
        }.to_h
      }
    end

    # The law, then slowest first, and off-highway last
    def state_classes(entries, law_id)
      entries.each_with_index.sort_by { |(_, id, record), index|
        [(id == law_id) ? 0 : 1, record["groups"].to_a.include?(OFF_HIGHWAY) ? 1 : 0, record["max_speed"] || Float::INFINITY, index]
      }.map { |(_, id, record), _| state_class(id, record) }
    end

    def state_class(id, record)
      {id:, name: record["name"], description: record["description"], throttle: record["throttle"], mph: mph(record["max_speed"]),
       watt_cap: record["max_power"], min_watts: record["min_power"]}
    end

    def mph(kilometers) = kilometers&.then { UnitSystem.kilometers_to_miles(it).round }

    def law(id, record)
      {
        id:,
        name: record["name"],
        description: record["description"],
        classes: record["groups"].to_a.filter_map { it[BikebookCatalog::US_CLASS, 1]&.to_i }.sort,
        watt_cap: record["max_power"],
        mph: mph(record["max_speed"]),
        throttle: record["throttle"],
        restrictions: record["restrictions"].to_a.map { restriction(it) },
        limits_start_on: date(record["limits_start_on"]),
        # link_to doesn't sanitize an href
        sources: record["sources"].to_a.grep(%r{\Ahttps?://})
      }
    end

    # link_to doesn't sanitize an href
    def restriction(value) = {rule: value["rule"], citation: value["citation"], sources: value["sources"].to_a.grep(%r{\Ahttps?://}),
                              starts_on: date(value["starts_on"]), ends_on: date(value["ends_on"])}

    def date(value) = value&.to_date

    def in_force(law, today)
      restrictions = law[:restrictions].reject { it[:ends_on]&.<=(today) }.map { it.merge(starts_on: upcoming(it[:starts_on], today)) }
      law.merge(restrictions:, limits_start_on: upcoming(law[:limits_start_on], today))
    end

    def upcoming(date, today) = (date if date&.>(today))

    conceal :parsed, :parse, :state_classes, :state_class, :mph, :law, :restriction, :date, :in_force, :upcoming
  end
end
