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
      FAILURES = [Faraday::Error, JSON::ParserError, SystemCallError, Unreachable].freeze

      # What a request has read, which Rails.cache would unmarshal a fresh copy of on each read
      class Reads < ActiveSupport::CurrentAttributes
        attribute :values, default: -> { {} }
      end

      # The model's title, description and image_url, nil for one the catalog hasn't. Raises Unreachable when it isn't
      # readable?
      def vehicle(id)
        raise Unreachable unless readable?

        model(id)&.then { {title: "#{it["manufacturer"]} #{it["model"]}", description: it["description"], image_url: it["stock_photo"]} }
      end

      # The model's record, its type schema 2.0.0's, nil for one the catalog hasn't. Raises Unreachable while the catalog
      # doesn't answer. Cached apart from its far larger block, under the manifest's digest: a cached one needs no
      # manifest read, and an updated catalog re-keys them all
      def model(id)
        return unless id.to_s.match?(MODEL_ID)
        raise Unreachable unless head

        record = cached(["bikebook_catalog/model", head["digest"], id], expires_in: 1.day) do
          block = (manifest || raise(Unreachable)).dig("blocks", id[MODEL_ID, 1])
          block && models_of(read(block))[id] || {}
        end
        (record || raise(Unreachable)).presence
      end

      # vehicle_models' entries: each vehicle's id, then in braces what's picked for it, m/trek/2026/marlin-5{size:M}{json}.
      # A name's commas are inside its braces
      def vehicle_entries(vehicle_models) = vehicle_models.to_s.scan(/(?:[^,{]|\{[^}]*\})+/)

      def vehicle_id(entry) = entry.split("{").first.strip

      # What every page reads of the manifest - its format, vocabulary file and digest - without the rest of it.
      # nil while the catalog doesn't answer
      def head = manifest_part(:head)

      # nil while the catalog doesn't answer
      def manifest = manifest_part(:manifest)

      # The file the catalog's laws and classifications are in, whose name is a digest of them
      def vocabulary = head&.dig("vocabulary")

      # Whether the catalog answers in the format /bikebook reads
      def readable? = head&.dig("format") == FORMAT

      # A published file, nil while the catalog doesn't answer. Its name is a digest of its contents,
      # so it keeps while it's published
      def file(path) = cached(["bikebook_catalog/file", 2, path], expires_in: 1.week) { read(path) }

      # Each schema document's fields, with the count of models holding each value and a few of them, and the file's
      # name, which carries a digest of its contents. nil while the catalog doesn't answer or names none
      def schema_viewer = manifest&.dig("schema_viewer")&.then { |name| file(name)&.merge("file" => name) }

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

      # Read once a request, as Reads resets with each request and job. A failure is kept for a minute, so a page reading
      # the catalog several times waits on it once, and nil isn't kept
      def cached(key, expires_in:)
        once(key) do
          Rails.cache.fetch(key, expires_in:, skip_nil: true) do |_key, options|
            yield
          rescue *FAILURES
            options.expires_in = 1.minute
            false
          end || nil
        end
      end

      # Drops what's cached under the key, for the rest of this request too
      def forget(key)
        Rails.cache.delete(key)
        Reads.values[key] = nil
      end

      #
      # private below here
      #

      # The head and the manifest are cached apart but always written together, so neither lags the catalog by more
      # than the 5 minutes each keeps
      def manifest_part(part)
        cached(manifest_key(part), expires_in: 5.minutes) do
          parts = fetched_manifest || raise(Unreachable)
          parts.except(part).each do |other, value|
            Rails.cache.write(manifest_key(other), value, expires_in: 5.minutes)
            Reads.values[manifest_key(other)] = value
          end
          parts[part]
        end
      end

      def manifest_key(part) = ["bikebook_catalog/#{part}", 2, MANIFEST]

      # Once a request even when it fails, which cached keeps only under the one key that read it
      def fetched_manifest
        once(:fetched_manifest) do
          body = body(MANIFEST)
          manifest = dashed_ids(JSON.parse(body))
          {head: manifest.slice("format", "vocabulary").merge("digest" => Digest::SHA256.hexdigest(body)), manifest:}
        rescue *FAILURES
          nil
        end
      end

      # A block's models by id, each market variant's beside its home market's
      def models_of(block) = Integrations::Bikebook::MarketVariants.expand(block["models"]).transform_values { it.merge("type" => current_slug(it["type"])) }

      def once(key) = Reads.values.fetch(key) { Reads.values[key] = yield }

      def read(path) = dashed_ids(JSON.parse(body(path)))

      def body(path) = LOCAL_DIRECTORY ? File.read(File.join(LOCAL_DIRECTORY, path)) : connection.get(path).body

      # An uncached file can take over 5s to start answering. A page waits on up to three - the manifest, the
      # vocabulary and a model's block - which give up inside rack-timeout's 30s unless a body trickles in
      def connection = Faraday.new(url: URL, request: {open_timeout: 2, timeout: 7}) { it.response :raise_error }

      conceal :manifest_part, :manifest_key, :fetched_manifest, :models_of, :once, :read, :body, :connection
    end
  end
end
