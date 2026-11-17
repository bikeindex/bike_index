# frozen_string_literal: true

module EbikeRuleServices
  # A Bike Book model's e-bike specs, read from the published catalog, which /bikebook searches
  module BikebookVehicles
    extend Functionable

    # nil for an id the catalog lacks, a model with no motor, or a catalog that doesn't answer
    def find(id)
      block = id.present? && Integrations::Bikebook::Catalog.manifest&.dig("blocks", id[Integrations::Bikebook::Catalog::MODEL_ID, 1])
      record = block && Integrations::Bikebook::Catalog.file(block)&.dig("models", id)
      Bike.new(**attributes_from(record)) if record && record["motors"].present?
    end

    #
    # private below here
    #

    def attributes_from(record)
      motors = record["motors"]
      modes = updated(motors.flat_map { it["operating_modes"] || [] })
      throttle_modes = modes.select { it["mode"] == "throttle" }
      assist_modes = modes.select { it["mode"] == "assist" }
      certifications = motors.map { it["certification"] }.join(", ")
      classifications = modes.flat_map { Array(it["e_vehicle_classifications"]) }.uniq
      tiers = classifications - EbikeRuleServices::StateLaws.e_bike_law_ids
      {
        bikebook_id: record["id"],
        manufacturer_name: record["manufacturer"],
        model: record["model"],
        first_year: record["first_year"],
        vehicle_type: record["type"] || "bike",
        e_bike_class: e_bike_class(tiers, modes, throttle_modes),
        class_unknown: tiers.none? && mph(modes).nil?,
        e_vehicle_classifications: classifications,
        optional_classes: optional_classes(modes),
        # a state's cap is on the motors together
        watts: total(motors, "rated_power"),
        peak_watts: total(motors, "peak_power"),
        top_assist_mph: mph(assist_modes),
        top_assist_kmh: kmh(assist_modes),
        assists_past_kmh: nil,
        throttle: throttle_modes.any?,
        stock_throttle: stock_throttle?(record, throttle_modes),
        throttle_mph: mph(throttle_modes),
        throttle_kmh: kmh(throttle_modes),
        ul2849: certifications.include?("UL 2849") ? :certified : :unknown,
        ul2271: certifications.include?("UL 2271") ? :certified : :unknown,
        photo_url: record["stock_photo"]
      }
    end

    # The highest US class any mode carries - assist to 28 mph with a throttle to 20 is Class 3. A mode
    # carrying another of the `tiers` (a moped, a motorcycle) makes it none. With none, its modes are classed by
    # the federal limits: 20 mph with a throttle, 28 without
    def e_bike_class(tiers, modes, throttle_modes)
      if tiers.any?
        return if tiers.any? { !it.match?(BikebookCatalog::US_CLASS) }

        return tiers.map { it[BikebookCatalog::US_CLASS, 1].to_i }.max
      end
      top_mph = mph(modes)
      return if top_mph.nil? || top_mph > 28
      return 3 if top_mph > 20

      throttle_modes.any? ? 2 : 1
    end

    # A throttle propulsion with no throttle mode is a stock throttle
    def stock_throttle?(record, throttle_modes)
      return Array(record["propulsion"]).include?("throttle") if throttle_modes.none?

      throttle_modes.any? { stock?(it) }
    end

    # None when every class is, as it's then sold as none of them
    def optional_classes(modes)
      stock, optional = modes.partition { stock?(it) }
      numbers = ->(mode) { Array(mode["e_vehicle_classifications"]).filter_map { it[BikebookCatalog::US_CLASS, 1]&.to_i } }
      sold = stock.flat_map(&numbers)
      return {} if sold.none?

      optional.flat_map { |mode| (numbers.call(mode) - sold).map { [it, mode["mode"]] } }.to_h
    end

    # A mode an app update unlocks is stock, not optional: a Class 1 whose app updates it to Class 3 is sold as a Class 3
    def stock?(mode) = [nil, "stock", "app_update"].include?(mode["availability"])

    # An app update replaces the modes of its kind the bike leaves the factory with, as a Class 3 assist does a Class 1's
    def updated(modes)
      kinds = modes.filter_map { it["mode"] if it["availability"] == "app_update" }
      modes.reject { [nil, "stock"].include?(it["availability"]) && kinds.include?(it["mode"]) }
    end

    def total(motors, power) = motors.filter_map { it[power] }.then { it.sum if it.any? }

    def mph(modes) = kmh(modes)&.then { UnitSystem.kilometers_to_miles(it).round }

    def kmh(modes) = modes.filter_map { it["max_speed"] }.max

    conceal :attributes_from, :e_bike_class, :stock_throttle?, :optional_classes, :stock?, :updated, :total, :mph, :kmh
  end
end
