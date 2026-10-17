# frozen_string_literal: true

module Integrations
  module Bikebook
    module Catalog
      extend Functionable

      # In development, a catalog `load:publish_catalog` wrote, served from here: its own app sends no CORS headers
      LOCAL_DIRECTORY = (ENV["BIKEBOOK_CATALOG_DIRECTORY"].presence if Rails.env.development?)
      LOCAL_PATH = "/bikebook_catalog"
      URL = "https://bikebook-catalog.bikeindex.org/catalog/"
      MANIFEST_URL = LOCAL_DIRECTORY ? "#{LOCAL_PATH}/manifest.json" : "#{URL}manifest.json"
      MODEL_ID = %r{\Am/([a-z0-9_]+/\d{4})/[a-z0-9_]+\z}

      Unreachable = Class.new(StandardError)

      # The model's title, description and image_url, nil for one the catalog hasn't. Raises Unreachable when it doesn't answer
      def vehicle(id)
        block = (manifest || raise(Unreachable)).dig("blocks", id[MODEL_ID, 1])
        model = block && (file(block) || raise(Unreachable)).dig("models", id)
        model && {title: "#{model["manufacturer"]} #{model["model"]}", description: model["description"], image_url: model["stock_photo"]}
      end

      # nil while the catalog doesn't answer
      def manifest = cached("bikebook_catalog/manifest", "manifest.json", expires_in: 5.minutes)

      # A published file, nil while the catalog doesn't answer. Its name is a digest of its contents,
      # so it keeps while it's published
      def file(path) = cached(["bikebook_catalog/file", path], path, expires_in: 1.week)

      #
      # private below here
      #

      # A failure is kept for a minute, so a page reading the catalog several times waits on it once
      def cached(key, path, expires_in:)
        Rails.cache.fetch(key, expires_in:) do |_key, options|
          read(path)
        rescue Faraday::Error, JSON::ParserError, SystemCallError
          options.expires_in = 1.minute
          false
        end || nil
      end

      def read(path)
        JSON.parse(LOCAL_DIRECTORY ? File.read(File.join(LOCAL_DIRECTORY, path)) : connection.get(path).body)
      end

      # A vehicle's page waits on it, so it gives up well inside rack-timeout's 30s
      def connection = Faraday.new(url: URL, request: {timeout: 5}) { it.response :raise_error }

      conceal :cached, :read, :connection
    end
  end
end
