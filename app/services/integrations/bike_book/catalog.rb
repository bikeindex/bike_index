# frozen_string_literal: true

module Integrations
  module BikeBook
    module Catalog
      extend Functionable

      # In development, a catalog `load:publish_catalog` wrote, served from here: its own app sends no CORS headers
      LOCAL_DIRECTORY = (ENV["BIKEBOOK_CATALOG_DIRECTORY"].presence if Rails.env.development?)
      LOCAL_PATH = "/bikebook_catalog"
      URL = "https://bikebook-catalog.bikeindex.org/catalog/"
      MANIFEST_URL = LOCAL_DIRECTORY ? "#{LOCAL_PATH}/manifest.json" : "#{URL}manifest.json"
      MODEL_ID = %r{\Am/([a-z0-9_]+/\d{4})/[a-z0-9_]+\z}

      # The model's title, description and image_url, nil for one the catalog hasn't. Raises Faraday::Error when it's unreachable
      def vehicle(id)
        blocks = Rails.cache.fetch("bikebook_catalog_blocks", expires_in: 5.minutes) { read("manifest.json")["blocks"] }
        block = blocks[id[MODEL_ID, 1]]
        block && summaries(block)[id]
      end

      #
      # private below here
      #

      # A block's filename is a digest of its contents, so its summaries keep while it's published
      def summaries(block)
        Rails.cache.fetch(["bikebook_catalog_block", block], expires_in: 1.week) do
          read(block)["models"].transform_values do |model|
            {title: "#{model["manufacturer"]} #{model["model"]}", description: model["description"], image_url: model["stock_photo"]}
          end
        end
      end

      def read(path)
        JSON.parse(LOCAL_DIRECTORY ? File.read(File.join(LOCAL_DIRECTORY, path)) : connection.get(path).body)
      end

      # A vehicle's page waits on it, so it gives up well inside rack-timeout's 30s
      def connection = Faraday.new(url: URL, request: {timeout: 5}) { it.response :raise_error }

      conceal :summaries, :read, :connection
    end
  end
end
