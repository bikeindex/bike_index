# frozen_string_literal: true

module Integrations
  module Bikebook
    # A record's own file in the bikebook repository. The published catalog reshapes components and classifications
    # into what references them, so it isn't the schema's JSON for them
    module RepositoryRecord
      extend Functionable

      URL = "https://raw.githubusercontent.com/bikeindex/bikebook/main/"
      DIRECTORIES = {"m" => "vehicle_models", "c" => "components", "evc" => "e_vehicle_classifications"}.freeze
      ID = %r{\A(m|c|evc)/([a-z0-9-]+(?:/[a-z0-9-]+)*)\z}

      # The file's JSON, nil for an id it has no file for. Raises Faraday::Error while GitHub doesn't answer
      def json(id)
        directory, path = id.to_s.match(ID)&.captures
        return unless directory

        Rails.cache.fetch(["bikebook/repository_record", id], expires_in: 1.hour) do
          connection.get("#{DIRECTORIES[directory]}/#{path}.json").body
        rescue Faraday::ResourceNotFound
          nil
        end
      end

      #
      # private below here
      #

      def connection = Faraday.new(url: URL, request: {open_timeout: 2, timeout: 7}) { it.response :raise_error }

      conceal :connection
    end
  end
end
