# frozen_string_literal: true

module Integrations
  module Bikebook
    module Catalog
      extend Functionable

      # In development, a catalog `load:publish_catalog` wrote, served from here: its own app sends no CORS headers
      LOCAL_DIRECTORY = (ENV["BIKEBOOK_CATALOG_DIRECTORY"].presence if Rails.env.development?)
      LOCAL_PATH = "/bikebook_catalog"
      URL = "https://bikebook-catalog.bikeindex.org/catalog/"
      # the published format bikebook/catalog_worker.js and similarity.js read
      FORMAT = 4
      MANIFEST = "manifest.#{FORMAT}.json"
      MANIFEST_URL = LOCAL_DIRECTORY ? "#{LOCAL_PATH}/#{MANIFEST}" : "#{URL}#{MANIFEST}"
      GITHUB_REPO_URL = "https://github.com/bikeindex/bikebook"
      MODEL_ID = %r{\Am/([a-z0-9_-]+/\d{4})/[a-z0-9_-]+\z}
      SCHEMA_VIEWER = Rails.root.join("config/bikebook_schema_viewer.json")
      # a model's, a component's or a classification's id, or a block's key: its maker and year
      CATALOG_ID = %r{\A(?:(?:m|c|evc)/[a-z0-9_/-]+|[a-z0-9_-]+/\d{4})\z}
      # The ids in a link's params: vehicle_models' among what's picked for each, the electric filter's US classes, and the
      # name non_e_bike_type is of a classification
      LINKED_PARAMS = %w[vehicle_models classifications electric classification].index_with(%r{\b(?:(?:m|c|evc)/[a-z0-9_/-]+|class_\d\b)})
        .merge("non_e_bike_type" => /\A[a-z0-9_]+\z/).freeze

      Unreachable = Class.new(StandardError)

      # The model's title, description and image_url, nil for one the catalog hasn't. Raises Unreachable when it isn't readable?
      def vehicle(id)
        raise Unreachable unless readable?
        model = (block_models(id) || raise(Unreachable))[id]
        model && {title: "#{model["manufacturer"]} #{model["model"]}", description: model["description"], image_url: model["stock_photo"]}
      end

      # vehicle_models' entries: each vehicle's id, then in braces what's picked for it, m/trek/2026/marlin-5{size:M}{json}.
      # A name's commas are inside its braces
      def vehicle_entries(vehicle_models) = vehicle_models.to_s.scan(/(?:[^,{]|\{[^}]*\})+/)

      def vehicle_id(entry) = entry.split("{").first.strip

      # nil while the catalog doesn't answer
      def manifest = cached(["bikebook_catalog/manifest", 2, MANIFEST], MANIFEST, expires_in: 5.minutes)

      # Whether the catalog answers in the format /bikebook reads. The e-bike law pages read the manifest regardless
      def readable? = manifest&.dig("format") == FORMAT

      # A published file, nil while the catalog doesn't answer. Its name is a digest of its contents,
      # so it keeps while it's published
      def file(path) = cached(["bikebook_catalog/file", 2, path], path, expires_in: 1.week)

      # The models of the block `id` is in, by id, empty for one the catalog hasn't. nil while the catalog doesn't answer
      def block_models(id)
        block = manifest&.dig("blocks", id.to_s[MODEL_ID, 1])
        block ? file(block)&.then { Integrations::Bikebook::MarketVariants.expand(it["models"]) } : {}
      end

      # Each schema document's fields, with the count of models holding each value and a few of them
      # TODO: read the catalog's published file, file(manifest["schema_viewer"]), once it publishes one
      def schema_viewer = JSON.parse(SCHEMA_VIEWER.read)

      # Schema 2.0.0's ids are dashed. An older catalog's are underscored and never dashed, so they read as 2.0.0's
      # TODO: once the published catalog is at 2.0.0, remove this
      def dashed_ids(value)
        case value
        when Hash then value.to_h { |key, each| [dashed_ids(key), dashed_ids(each)] }
        when Array then value.map { dashed_ids(it) }
        when CATALOG_ID then value.tr("_", "-")
        else value
        end
      end

      # A link's query with its ids dashed, which an older link's are not
      def dashed_query(query)
        query.to_h do |name, value|
          pattern = LINKED_PARAMS[name]
          [name, (pattern && value.is_a?(String)) ? value.gsub(pattern) { it.tr("_", "-") } : value]
        end
      end

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
        dashed_ids(JSON.parse(LOCAL_DIRECTORY ? File.read(File.join(LOCAL_DIRECTORY, path)) : connection.get(path).body))
      end

      # An uncached file can take over 5s to start answering. A page waits on up to three - the manifest, the
      # vocabulary and a model's block - which give up inside rack-timeout's 30s unless a body trickles in
      def connection = Faraday.new(url: URL, request: {open_timeout: 2, timeout: 7}) { it.response :raise_error }

      conceal :cached, :read, :connection
    end
  end
end
