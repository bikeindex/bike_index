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

      # Models by the manufacturer that have a stock photo and every word of `model` in their name - those
      # sold in `year` first. [] while the catalog doesn't answer
      def stock_photos(manufacturer:, model: nil, year: nil, limit: 6)
        slug = Slugifyer.manufacturer(manufacturer.to_s.presence)
        index = slug && manifest && file(manifest["index"])
        return [] if index.blank?

        words = model.to_s.downcase.split
        index["models"]
          .select { |model| model["manufacturer"] == slug && model["photo"].present? && words.all? { model["model"].downcase.include?(it) } }
          .partition { sold_in?(it, year.to_i) }.flatten.first(limit)
          .map {
          {id: it["id"], title: "#{it["manufacturer_name"]} #{it["model"]}", first_year: it["first_year"], final_year: it["final_year"],
           image_url: photo_url(index, it)}
        }
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

      def sold_in?(model, year) = year.positive? && model["first_year"] <= year && (model["final_year"] || year) >= year

      # An index photo is the file extension under the stock photo host, or a whole URL of its own
      def photo_url(index, model)
        return model["photo"] if model["photo"].include?("/")

        "#{index["stock_photos"]}/#{model["id"].delete_prefix("m/")}.#{model["photo"]}"
      end

      def read(path)
        JSON.parse(LOCAL_DIRECTORY ? File.read(File.join(LOCAL_DIRECTORY, path)) : connection.get(path).body)
      end

      # A vehicle's page waits on it, so it gives up well inside rack-timeout's 30s
      def connection = Faraday.new(url: URL, request: {timeout: 5}) { it.response :raise_error }

      conceal :cached, :sold_in?, :photo_url, :read, :connection
    end
  end
end
