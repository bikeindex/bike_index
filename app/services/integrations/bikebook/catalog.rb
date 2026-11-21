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
      MODEL_ID = %r{\Am/([a-z0-9_]+/\d{4})/[a-z0-9_]+\z}

      Unreachable = Class.new(StandardError)
      FAILURES = [Faraday::Error, JSON::ParserError, SystemCallError].freeze

      # What a request has read, which Rails.cache would unmarshal a fresh copy of on each read
      class Reads < ActiveSupport::CurrentAttributes
        attribute :values, default: -> { {} }
      end

      # The model's title, description and image_url, nil for one the catalog hasn't. Raises Unreachable when it isn't
      # readable?. Cached apart from its far larger block, under the manifest's digest: a cached one needs no manifest
      # read, and an updated catalog re-keys them all
      def vehicle(id)
        raise Unreachable unless readable?

        summary = cached(["bikebook_catalog/vehicle", head["digest"], id], expires_in: 1.day) do
          block = (manifest || raise(Unreachable)).dig("blocks", id[MODEL_ID, 1])
          model = block && read(block).dig("models", id)
          model ? {title: "#{model["manufacturer"]} #{model["model"]}", description: model["description"], image_url: model["stock_photo"]} : {}
        end
        (summary || raise(Unreachable)).presence
      end

      # vehicle_models' entries: each vehicle's id, then in braces what's picked for it, m/trek/2026/marlin_5{size:M}{json}.
      # A name's commas are inside its braces
      def vehicle_entries(vehicle_models) = vehicle_models.to_s.scan(/(?:[^,{]|\{[^}]*\})+/)

      def vehicle_id(entry) = entry.split("{").first.strip

      # What every page reads of the manifest - its format, vocabulary file and digest - without the rest of it.
      # nil while the catalog doesn't answer
      def head = once(:head) { manifest_part(:head) }

      # nil while the catalog doesn't answer
      def manifest = once(MANIFEST) { manifest_part(:manifest) }

      # Read once a request: Reads resets with each request and job
      def once(key) = Reads.values.fetch(key) { Reads.values[key] = yield }

      # Whether the catalog answers in the format /bikebook reads. The e-bike law pages read the manifest regardless
      def readable? = head&.dig("format") == FORMAT

      # A published file, nil while the catalog doesn't answer. Its name is a digest of its contents,
      # so it keeps while it's published
      def file(path) = cached(["bikebook_catalog/file", path], expires_in: 1.week) { read(path) }

      #
      # private below here
      #

      # The head and the manifest are cached apart but always written together, so neither lags the catalog by more
      # than the 5 minutes each keeps
      def manifest_part(part)
        Rails.cache.fetch(["bikebook_catalog/#{part}", MANIFEST], expires_in: 5.minutes) do |_key, options|
          parts = fetched_manifest
          if parts
            parts.except(part).each { |other, value| Rails.cache.write(["bikebook_catalog/#{other}", MANIFEST], value, expires_in: 5.minutes) }
            parts[part]
          else
            options.expires_in = 1.minute
            false
          end
        end || nil
      end

      def fetched_manifest
        once(:fetched_manifest) do
          body = body(MANIFEST)
          manifest = JSON.parse(body)
          {head: manifest.slice("format", "vocabulary").merge("digest" => Digest::SHA256.hexdigest(body)), manifest:}
        rescue *FAILURES
          nil
        end
      end

      # A failure is kept for a minute, so a page reading the catalog several times waits on it once
      def cached(key, expires_in:)
        Rails.cache.fetch(key, expires_in:) do |_key, options|
          yield
        rescue *FAILURES
          options.expires_in = 1.minute
          false
        end || nil
      end

      def read(path) = JSON.parse(body(path))

      def body(path) = LOCAL_DIRECTORY ? File.read(File.join(LOCAL_DIRECTORY, path)) : connection.get(path).body

      # An uncached file can take over 5s to start answering. A page waits on up to three - the manifest, the
      # vocabulary and a model's block - which give up inside rack-timeout's 30s unless a body trickles in
      def connection = Faraday.new(url: URL, request: {open_timeout: 2, timeout: 7}) { it.response :raise_error }

      conceal :manifest_part, :fetched_manifest, :cached, :read, :body, :connection
    end
  end
end
