# frozen_string_literal: true

module Integrations
  module BikebookCatalog
    extend Functionable

    # In development, a catalog `load:publish_catalog` wrote, served from here: its own app sends no CORS headers
    LOCAL_DIRECTORY = (ENV["BIKEBOOK_CATALOG_DIRECTORY"].presence if Rails.env.development?)
    LOCAL_PATH = "/bikebook_catalog"
    URL = "https://bikebook-catalog.bikeindex.org/catalog/"
    MANIFEST_URL = LOCAL_DIRECTORY ? "#{LOCAL_PATH}/manifest.json" : "#{URL}manifest.json"
    # A vehicle's page waits on it, so it gives up well inside rack-timeout's 30s
    TIMEOUT_SECONDS = 5
    MODEL_ID = %r{\Am/[a-z0-9_]+/\d{4}/[a-z0-9_]+\z}

    Vehicle = Data.define(:title, :description, :image_url)

    # The model `id` names, nil for one the catalog hasn't. Raises Faraday::Error when the catalog is unreachable
    def vehicle(id)
      return unless id.match?(MODEL_ID)

      blocks = Rails.cache.fetch("bikebook_catalog_blocks", expires_in: 5.minutes) { read("manifest.json")["blocks"] }
      block = blocks[id.split("/")[1, 2].join("/")]
      summary = block && summaries(block)[id]
      summary && Vehicle.new(**summary)
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

    def connection
      Faraday.new(url: URL) do |conn|
        conn.response :raise_error
        conn.options.timeout = TIMEOUT_SECONDS
        conn.adapter Faraday.default_adapter
      end
    end

    conceal :summaries, :read, :connection
  end
end
