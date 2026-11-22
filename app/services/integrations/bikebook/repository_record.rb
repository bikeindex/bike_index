# frozen_string_literal: true

module Integrations
  module Bikebook
    # A record's file in the bikebook repository; the published catalog reshapes components and classifications, so it
    # isn't their schema JSON
    module RepositoryRecord
      extend Functionable

      URL = "https://raw.githubusercontent.com/bikeindex/bikebook/main/"
      DIRECTORIES = {"m" => "vehicle_models", "c" => "components", "evc" => "e_vehicle_classifications"}.freeze
      ID = %r{\A(m|c|evc)/([a-z0-9/-]+)\z}

      Unreachable = Class.new(StandardError)

      # nil for an id with no file. A failure is kept for a minute, so GitHub being down holds up one request a minute
      def json(id)
        directory, path = id.match(ID)&.captures
        return unless directory

        Rails.cache.fetch(["bikebook/repository_record", id], expires_in: 1.hour) do |_key, options|
          Faraday.new(url: URL, request: {open_timeout: 2, timeout: 7}) { it.response :raise_error }
            .get("#{DIRECTORIES[directory]}/#{path}.json").body
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
