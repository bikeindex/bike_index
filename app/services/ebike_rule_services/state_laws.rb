# frozen_string_literal: true

module EbikeRuleServices
  # Each state's e-bike law, from the e-vehicle classifications in BikeBook's catalog
  module StateLaws
    extend Functionable

    # The 50 states and D.C., alphabetical
    STATES = StatesAndCountries.states.reject { it[:abbr] == "PR" }.freeze
    STATE_ID = %r{\Aevc/us/([a-z]{2})/}
    OFF_HIGHWAY = "evc/off_highway_motorcycle"
    MOTORCYCLE = "evc/motorcycle"
    ROAD_GROUPS = ["evc/moped", "evc/motor_driven_cycle", MOTORCYCLE].freeze
    RULE_GROUPS = %w[rider_rule enforcement legal_context seller_rule vehicle_definition].freeze
    TOP_RULE = /\Atop_rule_(\d+)\z/
    NAMED_CLASSES = /\bclass(?:es)? ((?:\d\b(?:,? (?:and|or) |, )?)+)/i
    # "Only Class 1 is allowed" tells the other classes they aren't
    ONLY_CLASS = /\bonly class \d|\bclass \d only\b/i
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

    # The top rules in force of the state's e-bike law for a class, without those only about other classes
    def e_bike_top_rules(abbreviation, e_bike_class:, today: Time.zone.today)
      top_rules(find(abbreviation, today:)&.dig(:restrictions).to_a).select { for_class?(it[:rule], e_bike_class) }
    end

    # The top rules in force for the state's motorcycle, which an e-moto usually is
    def emoto_rules(abbreviation, today: Time.zone.today) = top_rules(current(parsed[:motorcycles][abbreviation].to_a, today))

    # With its rule_groups, each leading with its top rules, and its top_rules. Each rule goes under the first group it's in
    def with_rule_groups(classification)
      top = ranked_top_rules(classification[:restrictions])
      rule_groups = (top + (classification[:restrictions] - top)).group_by { |rule| RULE_GROUPS.find { rule[:categories].include?(it) } || RULE_GROUPS.last }
      classification.merge(rule_groups: rule_groups.slice(*RULE_GROUPS), top_rules: top_rules(top))
    end

    # Any jurisdiction's classification by its ID, as a state's own classes are, the e-moto for an out of class marker,
    # nil for one the catalog lacks
    def classification(id)
      return NOT_AN_EBIKE if [NOT_AN_EBIKE[:id], *out_of_class_ids].include?(id)

      classifications[id]&.merge(CLASS_OVERRIDES.fetch(id, {}))
    end

    # The catalog's marker for a vehicle in no class in the state alone: California's evc/out_of_class/us/ca
    def out_of_class_id(abbreviation) = "#{NOT_AN_EBIKE[:id]}/us/#{abbreviation.downcase}"

    # The markers of the states whose law bars a Class 3's throttle, as California's does
    def out_of_class_ids = parsed[:laws].filter_map { |abbreviation, law| out_of_class_id(abbreviation) if law[:class_3_throttle] == false }

    # The classifications that are an e-bike law or class anywhere, as the EU's EPAC is, rather than a motor vehicle's
    def e_bike_law_ids = parsed[:e_bike_laws]

    # By ISO 3166-2 code, each place outside the US the catalog classifies e-vehicles in: its e-bike laws, or without
    # one of its own its country's, and its other classes, slowest first and off-highway last
    def places = vocabulary("places_with_rule_categories") { parse_places(it) } || {}

    # What a bike is checked against in a place outside the US: its own e-bike law, or without one, the class its
    # country's e-bike falls into there, a motor vehicle's, as New Brunswick's Motor Driven Cycle
    def place_law(code, today: Time.zone.today) = places.dig(code, :law)&.then { in_force(it, today) }

    def place_laws(today: Time.zone.today) = places.transform_values { it[:law]&.then { in_force(it, today) } }

    # nil for anything but an abbreviation, such as a query's array
    def state(abbreviation)
      STATES.find { it[:abbr] == abbreviation.upcase } if abbreviation.is_a?(String)
    end

    # The state's classification for a vehicle with these classifications, other than its e-bike law: its own, or one
    # sharing their group, with its restrictions not yet ended and its rule_groups
    def other_classification(abbreviation, ids, today: Time.zone.today)
      parsed => {groups:, tiers:}
      shared = ids.flat_map { [it, *groups[it]] }
      tiers[abbreviation]&.find { it[:ids].intersect?(shared) }&.then { with_rule_groups(in_force(it, today)) }
    end

    # Each of the state's classifications that isn't its e-bike law, with its rule_groups and top_rules, slowest and
    # least powerful first, off-highway last
    def non_e_bike_classifications(abbreviation, today: Time.zone.today)
      parsed[:tiers][abbreviation].to_a.sort_by.with_index { |tier, index| [*speed_rank(tier[:ids], tier[:kmh]), tier[:watt_cap] || Float::INFINITY, index] }
        .map { with_rule_groups(in_force(it, today)) }
    end

    # The lightest of the state's road classifications a vehicle whose record names none fits. Only a known speed is
    # within a speed cap; an unknown power is within any
    def classification_by_limits(abbreviation, mph:, watts:, today: Time.zone.today)
      fitting = parsed[:tiers][abbreviation].to_a.select { within_limits?(it, mph, watts) }
      ROAD_GROUPS.filter_map { |group| fitting.find { it[:ids].include?(group) } }.first
        &.then { with_rule_groups(in_force(it, today)).merge(by_limits: true) }
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

    def parsed = vocabulary("state_laws_with_rule_categories") { parse(it) } || {laws: {}, tiers: {}, groups: {}, classes: {}, motorcycles: {}, e_bike_laws: []}

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
        tiers: tiers.group_by(&:first).transform_values { it.map { |_, id, record| law(id, record).merge(ids: [id, *record["groups"]], value: id.split("/").last, min_watts: record["min_power"]) } },
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

    def by_speed(entries) = entries.each_with_index.sort_by { |(_, _, record), index| [*speed_rank(record["groups"].to_a, record["max_speed"]), index] }.map(&:first)

    # Slowest first, and off-highway last
    def speed_rank(groups, kmh) = [groups.include?(OFF_HIGHWAY) ? 1 : 0, kmh || Float::INFINITY]

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

    def restriction(value) = {rule: value["rule"], citation: value["citation"], categories: value["categories"].to_a, sources: web_pages(value["sources"]),
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

    def for_class?(rule, e_bike_class)
      classes = rule.scan(NAMED_CLASSES).join.scan(/\d/).map(&:to_i)
      classes.empty? || classes.include?(e_bike_class) || rule.match?(ONLY_CLASS)
    end

    def top_rules(restrictions) = ranked_top_rules(restrictions).select { it[:starts_on].nil? }

    def ranked_top_rules(restrictions) = restrictions.select { top_rule_rank(it) }.sort_by { top_rule_rank(it) }

    def top_rule_rank(restriction) = restriction[:categories].filter_map { it[TOP_RULE, 1]&.to_i }.first

    def within_limits?(tier, mph, watts)
      (tier[:mph].nil? || mph&.<=(tier[:mph])) && (watts.nil? || (tier[:min_watts]..tier[:watt_cap]).cover?(watts))
    end

    conceal :for_class?, :ranked_top_rules, :top_rule_rank, :parsed, :classifications, :vocabulary, :parse, :parse_places, :motor_vehicle_law, :state_classes, :by_speed, :speed_rank, :state_class, :metric?, :mph, :law, :restriction, :web_pages, :date, :in_force, :current, :upcoming, :top_rules, :within_limits?
  end
end
