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
      FORMAT = 6
      MANIFEST = "manifest.#{FORMAT}.json"
      MANIFEST_URL = LOCAL_DIRECTORY ? "#{LOCAL_PATH}/#{MANIFEST}" : "#{URL}#{MANIFEST}"
      GITHUB_REPO_URL = "https://github.com/bikeindex/bikebook"
      GITHUB_FILES_URL = "#{GITHUB_REPO_URL}/blob/main"
      MODEL_ID = %r{\Am/([a-z0-9-]+/\d{4})/[a-z0-9-]+(?:@[A-Z]+)?\z}
      # a market variant's citation key is its model's catalog id, @ and its market
      MARKET = /@([A-Z]+)\z/

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

      # The record of a catalog id or citation key, nil for one the catalog hasn't. Raises Unreachable while it doesn't answer
      def model(id) = model_markets(id)&.dig(id)

      # The records of the model and its market variants, by citation key, nil for a model the catalog hasn't. Raises
      # Unreachable while the catalog doesn't answer. Cached apart from their far larger block, under the manifest's
      # digest: a cached one needs no manifest read, and an updated catalog re-keys them all
      def model_markets(id)
        return unless id.to_s.match?(MODEL_ID)
        raise Unreachable unless head

        records = cached(["bikebook_catalog/model_markets", head["digest"], base_id(id)], expires_in: 1.day) do
          block = (manifest || raise(Unreachable)).dig("blocks", id[MODEL_ID, 1])
          (block ? read(block)["models"] : {}).select { |key, _| base_id(key) == base_id(id) }
        end
        (records || raise(Unreachable)).presence
      end

      def base_id(id) = id.to_s.sub(MARKET, "")

      # The catalog's market for a country's ISO code: it lists an EU member's models under the EU. The US for one that's
      # unknown, as Cloudflare's CF-IPCountry is XX, or T1 over Tor, when it can't tell
      def market(iso)
        return "US" if iso.blank? || %w[XX T1].include?(iso)

        EbikeRuleServices::Places::EU_MEMBERS.include?(iso) ? "EU" : iso
      end

      # The models of the index or a block, nil while the catalog doesn't answer. Uncached, as they're read by
      # BikebookModelsSyncJob, outside rack-timeout
      def file_models(path)
        read(path, timeout: 60)["models"]
      rescue *FAILURES
        nil
      end

      # vehicle_models' entries: each vehicle's id, then in braces what's picked for it, m/trek/2026/marlin-5{size:M}.
      # A name's commas are inside its braces
      def vehicle_entries(vehicle_models) = vehicle_models.to_s.scan(/(?:[^,{]|\{[^}]*\})+/)

      def vehicle_id(entry) = entry.split("{").first.strip

      # What every page reads of the manifest - its format, vocabulary file and digest - without the rest of it.
      # nil while the catalog doesn't answer
      def head = manifest_part(:head)

      # nil while the catalog doesn't answer
      def manifest = manifest_part(:manifest)

      # The vocabulary file, whose name is a digest of its contents
      def vocabulary = head&.dig("vocabulary")

      # What's at `keys` in the vocabulary, cached without the rest of the file. nil while the catalog doesn't answer
      def vocabulary_dig(*keys) = vocabulary&.then { file(it, *keys) }

      # Whether the catalog answers in the format /bikebook reads
      def readable? = head&.dig("format") == FORMAT

      # Each schema document's fields, with the count of models holding each value and a few of them, and the file's
      # name, which carries a digest of its contents. nil while the catalog doesn't answer or names none
      def schema_viewer = manifest&.dig("schema_viewer")&.then { |name| file(name)&.merge("file" => name) }

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

      # A published file, or what's at `keys` in it, nil while the catalog doesn't answer. Its name is a digest of its
      # contents, so it keeps while it's published
      def file(path, *keys)
        cached(["bikebook_catalog/file", 2, path, *keys], expires_in: 1.week) { read(path).then { keys.empty? ? it : it.dig(*keys) } }
      end

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
          manifest = JSON.parse(body)
          digest = Digest::SHA256.hexdigest(body)
          BikebookModelsSyncJob.enqueue_for(digest)
          {head: manifest.slice("format", "vocabulary").merge("digest" => digest), manifest:}
        rescue *FAILURES
          nil
        end
      end

      def once(key) = Reads.values.fetch(key) { Reads.values[key] = yield }

      def read(path, **) = JSON.parse(body(path, **))

      # An uncached file can take over 5s to start answering. A page waits on up to three - the manifest, the
      # vocabulary and a model's block - which give up inside rack-timeout's 30s unless a body trickles in
      def body(path, timeout: 7)
        return File.read(File.join(LOCAL_DIRECTORY, path)) if LOCAL_DIRECTORY

        Faraday.new(url: URL, request: {open_timeout: 2, timeout:}) { it.response :raise_error }.get(path).body
      end

      conceal :file, :manifest_part, :manifest_key, :fetched_manifest, :once, :read, :body
    end
  end
end
