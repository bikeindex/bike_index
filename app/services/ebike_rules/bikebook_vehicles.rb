# frozen_string_literal: true

module EbikeRules
  # A Bike Book model's e-bike specs, read from the published catalog, which /bikebook searches
  module BikebookVehicles
    extend Functionable

    # nil for an id the catalog lacks, a model with no motor, or a catalog that doesn't answer
    def find(id)
      return if id.blank?

      block = BikebookCatalog.manifest&.dig("blocks", id.delete_prefix("m/").split("/").first(2).join("/"))
      attributes = block && block_vehicles(block)&.dig(id)
      attributes && Bike.new(**attributes)
    end

    #
    # private below here
    #

    # Each motorized model in a block, a manufacturer's year. A block's file name carries its digest,
    # so a republished block is a new key
    def block_vehicles(block)
      Rails.cache.fetch(["bikebook_catalog/block_vehicles", block], expires_in: 1.week, skip_nil: true) do
        BikebookCatalog.fetch_json(block)&.dig("models")&.filter_map { |id, record| [id, attributes_from(record)] if record["motors"].present? }&.to_h
      end
    end

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
        e_vehicle_classifications: classifications,
        watts: motors.filter_map { it["rated_power"] }.max,
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
      tiers = classifications.grep_v(StateLaws::E_BIKE_LAW)
      if tiers.any?
        return if tiers.any? { !it.match?(StateLaws::US_CLASS) }

        return tiers.map { it[StateLaws::US_CLASS, 1].to_i }.max
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

    conceal :block_vehicles, :attributes_from, :e_bike_class, :mph
  end
end
