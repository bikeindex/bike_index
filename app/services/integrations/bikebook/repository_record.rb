# frozen_string_literal: true

module Integrations
  module Bikebook
    # A record's file in the bikebook repository; the published catalog reshapes components and classifications, so it
    # isn't their schema JSON
    module RepositoryRecord
      extend Functionable

      URL = "https://raw.githubusercontent.com/bikeindex/bikebook/main/"
      DOCUMENTS = {"m" => "vehicle_model", "c" => "component", "evc" => "e_vehicle_classification"}.freeze
      # a market variant's citation key, its home record's id and @ its market, is in its home record's file
      ID = %r{\A(m|c|evc)/([a-z0-9/-]+)(?:@[A-Z]+)?\z}

      Unreachable = Class.new(StandardError)

      # The schema document the record is, nil for an id that isn't a record's
      def document(id) = DOCUMENTS[id[ID, 1]]

      def path(id) = document(id)&.then { "#{it}s/#{id[ID, 2]}.json" }

      def github_url(id) = "#{Integrations::Bikebook::Catalog::GITHUB_FILES_URL}/#{path(id)}"

      # nil for an id with no file. A failure is kept for a minute, so GitHub being down holds up one request a minute
      def json(id)
        return unless path(id)

        Rails.cache.fetch(["bikebook/repository_record", path(id)], expires_in: 1.hour) do |_key, options|
          Faraday.new(url: URL, request: {open_timeout: 2, timeout: 7}) { it.response :raise_error }.get(path(id)).body
        rescue Faraday::ResourceNotFound
          nil
        rescue Faraday::Error
          options.expires_in = 1.minute
          false
        end.tap { raise Unreachable if it == false }
      end
    end
  end
end
