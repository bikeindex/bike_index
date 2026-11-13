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
      GITHUB_REPO_URL = "https://github.com/bikeindex/bikebook"
      MODEL_ID = %r{\Am/([a-z0-9_]+/\d{4})/[a-z0-9_]+\z}

      Unreachable = Class.new(StandardError)

      # The model's title, description and image_url, nil for one the catalog hasn't. Raises Unreachable when it doesn't answer
      def vehicle(id)
        block = (manifest || raise(Unreachable)).dig("blocks", id[MODEL_ID, 1])
        model = block && (file(block) || raise(Unreachable)).dig("models", id)
        model && {title: "#{model["manufacturer"]} #{model["model"]}", description: model["description"], image_url: model["stock_photo"]}
      end

      # vehicle_models' entries: each vehicle's id, then in braces what's picked for it, m/trek/2026/marlin_5{size:M}{json}.
      # A name's commas are inside its braces
      def vehicle_entries(vehicle_models) = vehicle_models.to_s.scan(/(?:[^,{]|\{[^}]*\})+/)

      def vehicle_id(entry) = entry.split("{").first.strip

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

      # An uncached file can take over 5s to start answering. A page waits on up to three - the manifest, the
      # vocabulary and a model's block - which give up inside rack-timeout's 30s unless a body trickles in
      def connection = Faraday.new(url: URL, request: {open_timeout: 2, timeout: 7}) { it.response :raise_error }

      conceal :cached, :read, :connection
    end
  end
end
