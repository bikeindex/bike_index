module Spreadsheets
  class ImporterJob < ApplicationJob
    RESOURCES_URL = "https://raw.githubusercontent.com/bikeindex/resources/refs/heads/main/data".freeze
    # Maps each importer module (e.g. Spreadsheets::Manufacturers) to its CSV filename in the resources repo
    IMPORTERS = {"manufacturers" => "manufacturers", "primary_activities" => "primary_activities", "components" => "component_types"}.freeze
    # db/seeds.rb runs this inline, so a transient blip reaching GitHub would abort the
    # whole seed (e.g. CI). Retry a few times before giving up. Parallel CI shards all
    # hit raw.githubusercontent.com at once, so 429 rate-limits are the common failure.
    DOWNLOAD_ATTEMPTS = 4
    RETRY_DELAY_SECONDS = 2
    RETRYABLE_STATUSES = [429, 500, 502, 503, 504].freeze

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
        return response.body if response.success?

        # Faraday::Error (not a plain RuntimeError) so the rescue below retries it
        raise Faraday::Error, "Failed to fetch #{url}: #{response.status}" if RETRYABLE_STATUSES.include?(response.status)
        raise "Failed to fetch #{url}: #{response.status}"
      rescue Faraday::Error
        raise if attempt >= DOWNLOAD_ATTEMPTS
        sleep RETRY_DELAY_SECONDS * attempt
        retry
      end
    end

    def connection
      Faraday.new do |faraday|
        faraday.use FaradayMiddleware::FollowRedirects, limit: 15
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = 30
        faraday.options.open_timeout = 10
      end
    end
  end
end
