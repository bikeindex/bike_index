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
      modes = motors.flat_map { it["operating_modes"] || [] }
      throttle_modes = modes.select { it["mode"] == "throttle" }
      certifications = motors.map { it["certification"] }.join(", ")
      # a single classification is schema 0.22's, which models not yet reconciled to 0.23 still carry
      classifications = modes.flat_map { Array(it["e_vehicle_classifications"] || it["e_vehicle_classification"]) }.uniq
      {
        bikebook_id: record["id"],
        manufacturer_name: record["manufacturer"],
        model: record["model"],
        first_year: record["first_year"],
        e_bike_class: e_bike_class(classifications, modes, throttle_modes),
        class_unknown: classifications.grep_v(BikebookCatalog::E_BIKE_LAW).none? && mph(modes).nil?,
        e_vehicle_classifications: classifications,
        # a state's cap is on the motors together
        watts: motors.filter_map { it["rated_power"] }.then { it.sum if it.any? },
        top_assist_mph: mph(modes.select { it["mode"] == "assist" }),
        throttle: throttle_modes.any?,
        throttle_mph: mph(throttle_modes),
        ul2849: certifications.include?("UL 2849") ? :certified : :unknown,
        ul2271: certifications.include?("UL 2271") ? :certified : :unknown,
        photo_url: record["stock_photo"]
      }
    end

    # The highest US class any mode carries - assist to 28 mph with a throttle to 20 is Class 3. A mode
    # carrying another classification (a moped, a motorcycle), other than an e-bike law, makes it none.
    # Unclassified modes are classed by the federal limits: 20 mph with a throttle, 28 without
    def e_bike_class(classifications, modes, throttle_modes)
      tiers = classifications.grep_v(BikebookCatalog::E_BIKE_LAW)
      if tiers.any?
        return if tiers.any? { !it.match?(BikebookCatalog::US_CLASS) }

        return tiers.map { it[BikebookCatalog::US_CLASS, 1].to_i }.max
      end
      top_mph = mph(modes)
      return if top_mph.nil? || top_mph > 28
      return 3 if top_mph > 20

      throttle_modes.any? ? 2 : 1
    end

    def mph(modes)
      kilometers = modes.filter_map { it["max_speed"] }.max
      kilometers && UnitSystem.kilometers_to_miles(kilometers).round
    end

    conceal :attributes_from, :e_bike_class, :mph
  end
end
