# frozen_string_literal: true

module EbikeRules
  # A Bike Book model's e-bike specs, read from the catalog /bikebook publishes
  module BikebookVehicles
    extend Functionable

    CATALOG_URL = "https://bikebook-catalog.bikeindex.org/catalog/"
    KILOMETERS_PER_MILE = 1.609344
    US_CLASS = %r{\Aevc/us/class_(\d)\z}

    # nil for an id the catalog lacks, a model with no motor, or a catalog that doesn't answer
    def find(id)
      return if id.blank?

      # a block's file name carries its digest, so a republished block is a new key
      block = manifest&.dig("blocks", block_key(id))
      return if block.nil?

      attributes = Rails.cache.fetch(["ebike_rules/bikebook_vehicle", block, id], expires_in: 1.week, skip_nil: true) do
        record = fetch_json(block)&.dig("models", id)
        attributes_from(record) if record&.dig("motors").present?
      end
      attributes && Bike.new(**attributes)
    end

    # Every US class a mode carries, the highest of them - assist to 28 mph with a throttle to 20 is
    # Class 3. A mode carrying another classification (a moped, a motorcycle) makes it none
    def e_bike_class(modes)
      classifications = modes.map { it["e_vehicle_classification"] }.compact
      return classes_from_speeds(modes) if classifications.none?
      return if classifications.any? { !it.match?(US_CLASS) }

      classifications.map { it[US_CLASS, 1].to_i }.max
    end

    #
    # private below here
    #

    def attributes_from(record)
      motors = record["motors"]
      modes = motors.flat_map { it["operating_modes"] || [] }
      certifications = motors.map { it["certification"] }.join(", ")
      {
        bikebook_id: record["id"],
        manufacturer_name: record["manufacturer"],
        model: record["model"],
        first_year: record["first_year"],
        e_bike_class: e_bike_class(modes),
        watts: motors.filter_map { it["rated_power"] }.max,
        top_assist_mph: mph(modes.select { it["mode"] == "assist" }),
        throttle: modes.any? { it["mode"] == "throttle" },
        throttle_mph: mph(modes.select { it["mode"] == "throttle" }),
        ul2849: certifications.include?("UL 2849") ? :certified : :unknown,
        ul2271: certifications.include?("UL 2271") ? :certified : :unknown,
        photo_url: record["stock_photo"]
      }
    end

    # Unclassified modes, by the federal limits: 20 mph with a throttle or 28 mph without
    def classes_from_speeds(modes)
      top_mph = mph(modes)
      return if top_mph.nil? || top_mph > 28
      return 3 if top_mph > 20

      (modes.any? { it["mode"] == "throttle" }) ? 2 : 1
    end

    def mph(modes)
      kilometers = modes.filter_map { it["max_speed"] }.max
      kilometers && (kilometers / KILOMETERS_PER_MILE).round
    end

    def block_key(id) = id.delete_prefix("m/").split("/").first(2).join("/")

    def manifest
      Rails.cache.fetch("ebike_rules/bikebook_manifest", expires_in: 1.hour, skip_nil: true) { fetch_json("manifest.json") }
    end

    def fetch_json(path)
      response = Faraday.new(url: CATALOG_URL, request: {timeout: 5}).get(path)
      JSON.parse(response.body) if response.success?
    rescue Faraday::Error, JSON::ParserError
      nil
    end

    conceal :attributes_from, :classes_from_speeds, :mph, :block_key, :manifest, :fetch_json
  end
end
