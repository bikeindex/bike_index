# frozen_string_literal: true

module EbikeRules
  # A Bike Book model's e-bike specs, read from the published catalog, which /bikebook searches
  module BikebookVehicles
    extend Functionable

    US_CLASS = %r{\Aevc/us/class_(\d)\z}

    # nil for an id the catalog lacks, a model with no motor, or a catalog that doesn't answer
    def find(id)
      return if id.blank?

      block = blocks&.dig(id.delete_prefix("m/").split("/").first(2).join("/"))
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
        fetch_json(block)&.dig("models")&.filter_map { |id, record| [id, attributes_from(record)] if record["motors"].present? }&.to_h
      end
    end

    def attributes_from(record)
      motors = record["motors"]
      modes = motors.flat_map { it["operating_modes"] || [] }
      throttle_modes = modes.select { it["mode"] == "throttle" }
      certifications = motors.map { it["certification"] }.join(", ")
      {
        bikebook_id: record["id"],
        manufacturer_name: record["manufacturer"],
        model: record["model"],
        first_year: record["first_year"],
        e_bike_class: e_bike_class(modes, throttle_modes),
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
    # carrying another classification (a moped, a motorcycle) makes it none. Unclassified modes are
    # classed by the federal limits: 20 mph with a throttle, 28 without
    def e_bike_class(modes, throttle_modes)
      classifications = modes.filter_map { it["e_vehicle_classification"] }
      if classifications.any?
        return if classifications.any? { !it.match?(US_CLASS) }

        return classifications.map { it[US_CLASS, 1].to_i }.max
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

    def blocks
      Rails.cache.fetch("bikebook_catalog/blocks", expires_in: 1.hour, skip_nil: true) { fetch_json("manifest.json")&.dig("blocks") }
    end

    def fetch_json(path)
      response = Faraday.new(url: BikebookController::CATALOG_URL, request: {timeout: 5}).get(path)
      JSON.parse(response.body) if response.success?
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    conceal :block_vehicles, :attributes_from, :e_bike_class, :mph, :blocks, :fetch_json
  end
end
