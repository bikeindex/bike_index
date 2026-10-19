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
    NOT_AN_EBIKE = {id: "evc/out_of_class", not_an_ebike: true}.freeze
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

    def three_classes?(law) = law[:classes] == [1, 2, 3]

    # The helmet, age and path rules in force for a Class 3 under the state's e-bike law
    def class_3_rules(abbreviation, today: Time.zone.today)
      find(abbreviation, today:)&.dig(:restrictions).to_a
        .select { it[:starts_on].nil? && it[:rule].match?(/\bclass 3\b/i) && it[:rule].match?(/helmet|older|\bage\b|path|trail/i) }
    end

    # The license, registration and insurance rules in force for the state's motorcycle, which an e-moto usually is
    def emoto_rules(abbreviation, today: Time.zone.today)
      current(parsed[:motorcycles][abbreviation].to_a, today).select { it[:starts_on].nil? && it[:rule].match?(/licen|regist|insur/i) }
    end

    # Any jurisdiction's classification by its ID, as a state's own classes are, the e-moto for an out of class marker,
    # nil for one the catalog lacks
    def classification(id)
      return NOT_AN_EBIKE if [nil, *class_3_throttle_bars].map { out_of_class_id(it) }.include?(id)

      classifications[id]&.merge(CLASS_OVERRIDES.fetch(id, {}))
    end

    # The catalog's marker for a vehicle in no class, or in none in `jurisdiction` alone, US-CA's evc/out_of_class/us/ca
    def out_of_class_id(jurisdiction = nil) = [NOT_AN_EBIKE[:id], jurisdiction&.downcase&.tr("-", "/")].compact.join("/")

    # By ISO 3166-2 code, the states whose law bars a Class 3's throttle, as California's does
    def class_3_throttle_bars = laws.filter_map { |abbreviation, law| "US-#{abbreviation}" if law[:class_3_throttle] == false }

    # The classifications that are an e-bike law or class anywhere, as the EU's EPAC is, rather than a motor vehicle's
    def e_bike_law_ids = parsed[:e_bike_laws]

    # By ISO 3166-2 code, each place outside the US the catalog classifies e-vehicles in: its e-bike laws, or without
    # one of its own its country's, and its other classes, slowest first and off-highway last
    def places = vocabulary("places_with_laws") { parse_places(it) } || {}

    # What a bike is checked against in a place outside the US: its own e-bike law, or without one, the class its
    # country's e-bike falls into there, a motor vehicle's, as New Brunswick's Motor Driven Cycle
    def place_law(code, today: Time.zone.today) = places.dig(code, :law)&.then { in_force(it, today) }

    def place_laws(today: Time.zone.today) = places.transform_values { it[:law]&.then { in_force(it, today) } }

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

    def parsed = vocabulary("state_laws_with_e_bike_laws") { parse(it) } || {laws: {}, tiers: {}, groups: {}, classes: {}, motorcycles: {}, e_bike_laws: []}

    # apart from parsed, which every state's lookup reads
    def classifications
      vocabulary("classifications") { |records| records.to_h { |id, record| [id, state_class(id, record).merge(jurisdiction: record["jurisdiction"])] } } || {}
    end

    # The vocabulary's classifications as the block reads them. Its file name carries its digest, so a republished one
    # is a new key
    def vocabulary(name)
      path = Integrations::Bikebook::Catalog.manifest&.dig("vocabulary")
      path && Rails.cache.fetch(["bikebook_catalog/#{name}", path], expires_in: 1.week, skip_nil: true) do
        Integrations::Bikebook::Catalog.file(path)&.dig("e_vehicle_classifications")&.then { yield it }
      end
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
        e_bike_laws: records.filter_map { |id, record| id if record["e_bike_law"] },
        classes: states.group_by(&:first).filter_map { |abbreviation, entries|
          law = laws[abbreviation]
          next if law.nil? || three_classes?(law)

          [abbreviation, state_classes(entries, law[:id])]
        }.to_h,
        motorcycles: states.filter_map { |abbreviation, id, record|
          next unless id.end_with?("/motorcycle") || record["groups"].to_a.include?(MOTORCYCLE)

          [abbreviation, record["restrictions"].to_a.map { restriction(it) }]
        }.to_h
      }
    end

    def parse_places(records)
      by_place = records.filter_map { |id, record| [record["jurisdiction"], id, record] if metric?(record) }.group_by(&:first)
      # one of a wider law's ahead of the place's own, as Ontario's Power-Assisted Bicycle is of its Cargo one
      laws = by_place.transform_values do |place_entries|
        place_entries.select { it[2]["e_bike_law"] }.partition { it[2]["groups"].present? }.flatten(1).map { law(it[1], it[2]) }
      end
      by_place.to_h do |code, place_entries|
        country_laws = laws[code.split("-").first].to_a
        others = by_speed(place_entries.reject { it[2]["e_bike_law"] })
        [code, {laws: laws[code].presence || country_laws, classes: others.map { |_, id, record| state_class(id, record) },
                law: laws[code]&.first || motor_vehicle_law(others, country_laws)}]
      end
    end

    def motor_vehicle_law(entries, country_laws)
      ids = country_laws.map { it[:id] }
      _, id, record = entries.find { it[2]["groups"].to_a.intersect?(ids) }
      id && law(id, record).merge(motor_vehicle: true)
    end

    def state_classes(entries, law_id)
      law, others = entries.partition { it[1] == law_id }
      (law + by_speed(others)).map { |_, id, record| state_class(id, record) }
    end

    # Slowest first, and off-highway last
    def by_speed(entries)
      entries.each_with_index.sort_by { |(_, _, record), index|
        [record["groups"].to_a.include?(OFF_HIGHWAY) ? 1 : 0, record["max_speed"] || Float::INFINITY, index]
      }.map(&:first)
    end

    def state_class(id, record)
      {id:, name: record["name"], description: record["description"], throttle: record["throttle"], mph: mph(record["max_speed"]),
       kmh: record["max_speed"], metric: metric?(record), watt_cap: record["max_power"], min_watts: record["min_power"]}
    end

    # Outside the US, where a limit reads in km/h
    def metric?(record) = record["jurisdiction"].present? && !record["jurisdiction"].match?(/\AUS\b/)

    def mph(kilometers) = kilometers&.then { UnitSystem.kilometers_to_miles(it).round }

    def law(id, record)
      {
        id:,
        name: record["name"],
        description: record["description"],
        classes: record["groups"].to_a.filter_map { it[BikebookCatalog::US_CLASS, 1]&.to_i }.sort,
        watt_cap: record["max_power"],
        mph: mph(record["max_speed"]),
        kmh: record["max_speed"],
        metric: metric?(record),
        throttle: record["throttle"],
        # false where a Class 3 can't have a throttle at all, as California's can't
        class_3_throttle: record["class_3_throttle"],
        restrictions: record["restrictions"].to_a.map { restriction(it) },
        limits_start_on: date(record["limits_start_on"]),
        sources: web_pages(record["sources"])
      }
    end

    def restriction(value) = {rule: value["rule"], citation: value["citation"], sources: web_pages(value["sources"]),
                              starts_on: date(value["starts_on"]), ends_on: date(value["ends_on"])}

    # link_to doesn't sanitize an href
    def web_pages(sources) = sources.to_a.grep(%r{\Ahttps?://})

    def date(value) = value&.to_date

    def in_force(law, today)
      law.merge(restrictions: current(law[:restrictions], today), limits_start_on: upcoming(law[:limits_start_on], today))
    end

    # The restrictions not yet ended, each keeping its start date only until it starts
    def current(restrictions, today) = restrictions.reject { it[:ends_on]&.<=(today) }.map { it.merge(starts_on: upcoming(it[:starts_on], today)) }

    def upcoming(date, today) = (date if date&.>(today))

    conceal :parsed, :classifications, :vocabulary, :parse, :parse_places, :motor_vehicle_law, :state_classes, :by_speed, :state_class, :metric?, :mph, :law, :restriction, :web_pages, :date, :in_force, :current, :upcoming
  end
end
