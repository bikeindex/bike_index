# frozen_string_literal: true

module EbikeRuleServices
  # The published Bike Book catalog, which /bikebook searches. Each read is nil when it doesn't answer
  module BikebookCatalog
    extend Functionable

    # A jurisdiction's whole e-bike law, rather than one class or tier of it
    E_BIKE_LAW = %r{/(electric_bicycle|bicycle|low_speed_electric_bicycle)\z}
    US_CLASS = %r{\Aevc/us/class_(\d)\z}

    def manifest
      Rails.cache.fetch("bikebook_catalog/manifest", expires_in: 1.hour, skip_nil: true) { fetch_json("manifest.json") }
    end

    def fetch_json(path)
      response = Faraday.new(url: Integrations::Bikebook::Catalog::URL, request: {timeout: 5}).get(path)
      JSON.parse(response.body) if response.success?
    rescue Faraday::Error, JSON::ParserError
      nil
    end
  end
end
