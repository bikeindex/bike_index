module Spreadsheets
  class ImporterJob < ApplicationJob
    RESOURCES_URL = "https://raw.githubusercontent.com/bikeindex/bike_data/refs/heads/main/data".freeze
    # Maps each importer module (e.g. Spreadsheets::Manufacturers) to its CSV filename in the bike_data repo
    IMPORTERS = {"manufacturers" => "manufacturers", "primary_activities" => "primary_activities", "components" => "component_types"}.freeze
    # db/seeds.rb runs this inline, so a transient blip reaching GitHub would abort the
    # whole seed (e.g. CI). Retry a few times before giving up.
    DOWNLOAD_ATTEMPTS = 3
    RETRY_DELAY_SECONDS = 2

    def perform(name = nil)
      return IMPORTERS.each_key { |n| perform(n) } if name.blank?
      filename = IMPORTERS[name]
      raise ArgumentError, "Unknown importer: #{name.inspect} (expected one of #{IMPORTERS.keys.join(", ")})" unless filename

      # binmode: write the downloaded bytes verbatim. The CSVs are UTF-8 and Faraday
      # returns ASCII-8BIT, which text mode tries to transcode (failing on CI, where
      # the container has no UTF-8 locale).
      Tempfile.create([name, ".csv"], binmode: true) do |file|
        file.write(download("#{RESOURCES_URL}/#{filename}.csv"))
        file.flush
        Spreadsheets.const_get(name.camelize).import(file.path)
      end
    end

    private

    def download(url)
      attempt = 0
      begin
        attempt += 1
        response = connection.get(url)
        raise "Failed to fetch #{url}: #{response.status}" unless response.success?

        response.body
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError
        raise if attempt >= DOWNLOAD_ATTEMPTS
        sleep RETRY_DELAY_SECONDS
        retry
      end
    end

    def connection
      Faraday.new do |faraday|
        faraday.use Faraday::FollowRedirects::Middleware, limit: 15
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = 30
        faraday.options.open_timeout = 10
      end
    end
  end
end
