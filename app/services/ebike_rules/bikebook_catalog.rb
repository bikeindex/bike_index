# frozen_string_literal: true

module EbikeRules
  # The published Bike Book catalog, which /bikebook searches. Each read is nil when it doesn't answer
  module BikebookCatalog
    extend Functionable

    def manifest
      Rails.cache.fetch("bikebook_catalog/manifest", expires_in: 1.hour, skip_nil: true) { fetch_json("manifest.json") }
    end

    def fetch_json(path)
      response = Faraday.new(url: BikebookController::CATALOG_URL, request: {timeout: 5}).get(path)
      JSON.parse(response.body) if response.success?
    rescue Faraday::Error, JSON::ParserError
      nil
    end
  end
end
