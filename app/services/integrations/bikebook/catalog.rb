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
      # The ids in a link's params: vehicle_models' among what's picked for each, and the electric filter's US classes
      LINKED_ID = %r{\b(?:(?:m|c|evc)/[a-z0-9_/-]+|class_\d\b)}
      # Schema 2.0.0's slugs for the vocabulary Bike Index reads values of, which an older catalog underscores, and where
      # 2.0.0 renamed one, names otherwise. bikebook/catalog_worker.js reads them the same way
      # TODO: once the published catalog is at 2.0.0, and an older link's slugs have had a year to move, remove this
      RENAMED = {
        "bike_trailer" => "trailer",
        "cargo_bike" => "cargo",
        "cargo_bike_rear" => "cargo-rear",
        "cargo_tricycle" => "cargo-trike",
        "cargo_tricycle_rear" => "cargo-trike-rear",
        "epamd" => "personal-mobility",
        "scooter" => "non-e-scooter",
        "skateboard" => "non-e-skateboard",
        "elliptical_bike" => "elliptical",
        "road_endurance" => "road-endurance-sportive",
        "carbon" => "composite",
        "wood" => "organic"
      }.freeze

      Unreachable = Class.new(StandardError)

      # The model's title, description and image_url, nil for one the catalog hasn't. Raises Unreachable when it isn't readable?
      def vehicle(id)
        raise Unreachable unless readable?
        model = (block_models(id) || raise(Unreachable))[id]
        model && {title: "#{model["manufacturer"]} #{model["model"]}", description: model["description"], image_url: model["stock_photo"]}
      end

      # The catalog's market for a country's ISO code: it lists an EU member's models under the EU
      def market(iso) = EbikeRuleServices::Places::EU_MEMBERS.include?(iso) ? "EU" : iso

      # The index's models, nil while the catalog doesn't answer. Too big to cache, and read by a job, outside rack-timeout
      def index_models(path)
        read(path, timeout: 60)["models"]
      rescue Faraday::Error, JSON::ParserError, SystemCallError
        nil
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

      # The models of the block `id` is in, by id, each type schema 2.0.0's, empty for one the catalog hasn't. nil while the
      # catalog doesn't answer
      def block_models(id)
        block = manifest&.dig("blocks", id.to_s[MODEL_ID, 1])
        return {} unless block

        file(block)&.then do |published|
          Integrations::Bikebook::MarketVariants.expand(published["models"]).transform_values { it.merge("type" => current_slug(it["type"])) }
        end
      end

      # Each schema document's fields, with the count of models holding each value and a few of them, and the digest
      # of its contents that its rendering is cached under
      # TODO: read the catalog's published file, file(manifest["schema_viewer"]), once it publishes one, whose name
      # carries its digest
      def schema_viewer = SCHEMA_VIEWER.read.then { {**JSON.parse(it), "digest" => Digest::SHA256.hexdigest(it)} }

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

      def current_slug(value) = RENAMED[value] || value&.tr("_", "-")

      # A link's query with its ids and slugs schema 2.0.0's, which an older link's are not. non_e_bike_type is a
      # classification's name
      def dashed_query(query)
        query.to_h do |name, value|
          next [name, value] unless value.is_a?(String)

          [name, case name
                 when "vehicle_models", "classifications", "electric", "classification" then value.gsub(LINKED_ID) { it.tr("_", "-") }
                 when "primary_activity", "vehicle_type", "frame_material" then value.gsub(/[^,]+/) { current_slug(it) }
                 when "manufacturer", "non_e_bike_type" then value.tr("_", "-")
                 else value
                 end]
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

      # An uncached file can take over 5s to start answering. A page waits on up to three - the manifest, the
      # vocabulary and a model's block - which give up inside rack-timeout's 30s unless a body trickles in
      def read(path, timeout: 7)
        dashed_ids(JSON.parse(LOCAL_DIRECTORY ? File.read(File.join(LOCAL_DIRECTORY, path)) : connection(timeout).get(path).body))
      end

      def connection(timeout) = Faraday.new(url: URL, request: {open_timeout: 2, timeout:}) { it.response :raise_error }

      conceal :cached, :read, :connection
    end
  end
end
