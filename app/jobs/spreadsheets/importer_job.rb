module Spreadsheets
  class ImporterJob < ApplicationJob
    RESOURCES_URL = "https://raw.githubusercontent.com/bikeindex/resources/refs/heads/main/data".freeze
    # Each name is both the CSV filename and the importer module (e.g. Spreadsheets::Manufacturers)
    IMPORTERS = %w[manufacturers primary_activities components].freeze

    def perform(name = nil)
      return IMPORTERS.each { |n| self.class.perform_async(n) } if name.blank?

      Tempfile.create([name, ".csv"]) do |file|
        file.write(download("#{RESOURCES_URL}/#{name}.csv"))
        file.flush
        Spreadsheets.const_get(name.camelize).import(file.path)
      end
    end

    private

    def download(url)
      conn = Faraday.new do |faraday|
        faraday.use FaradayMiddleware::FollowRedirects, limit: 15
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = 30
        faraday.options.open_timeout = 5
      end
      response = conn.get(url)
      raise "Failed to fetch #{url}: #{response.status}" unless response.success?

      response.body
    end
  end
end
