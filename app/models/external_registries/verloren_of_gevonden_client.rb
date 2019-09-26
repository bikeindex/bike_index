# frozen_string_literal: true

module ExternalRegistries
  class VerlorenOfGevondenClient
    attr_accessor :conn, :base_url, :result_pages, :total_results, :total_pages,
                  :request_gap_seconds, :backoff, :backoff_factor, :retry_pages,
                  :backoff_max

    # The API responds with 10 items per page of results
    ITEMS_RECEIVED_PER_PAGE = 10

    MINIMUM_QUERY_LENGTH = 3
    START_DATE = 1.year.ago.beginning_of_month
    TTL_HOURS = ENV.fetch("VERLOREN_OF_GEVONDEN_TTL_HOURS", 24).to_i.hours

    def initialize(base_url: nil)
      self.base_url = base_url || ENV["VERLOREN_OF_GEVONDEN_BASE_URL"]
      self.request_gap_seconds = 1
      self.backoff = 0
      self.backoff_max = 60
      self.backoff_factor = 5
      self.retry_pages = []
      self.conn = Faraday.new(url: self.base_url) do |conn|
        conn.response :json, content_type: /\bjson$/
        conn.use Faraday::RequestResponseLogger::Middleware,
                 logger_level: :info,
                 logger: Rails.logger if Rails.env.development?
        conn.adapter Faraday.default_adapter
      end
      self.result_pages = {}
    end

    # Return an ActiveRecord collection of ExternalRegistryBike objects
    def search(query, all_pages: true)
      return ::ExternalRegistryBike.none if query.to_s.length < MINIMUM_QUERY_LENGTH

      get_page(query)

      if all_pages && total_pages.to_i > 1
        (2..total_pages)
          .map { |page| Thread.new { get_page(query, page: page) } }
          .map(&:value)

        retry_pages
          .each { |page| Rails.logger.info("Retrying page #{page}") }
          .map { |page| Thread.new { get_page(query, page: page) } }
          .map(&:value)
      end

      persisted = external_registry_bikes_from(result_pages: result_pages.values.flatten.compact)
      ::ExternalRegistryBike.where(id: persisted.map(&:id))
    end

    private

    # Query for the results page `page_num`.
    # Return the JSON response body as a Hash
    def get_page(query, page: 1, per_page: ITEMS_RECEIVED_PER_PAGE)
      Rails.logger.info("Requesting page #{page}")
      req_params = request_params(query, page, per_page)
      cache_key = ["verlorenofgevonden.nl", query, req_params]

      response_json =
        Rails.cache.fetch(cache_key, expires_in: TTL_HOURS) do
          sleep(self.request_gap_seconds)
          response = conn.post("ez.php") do |req|
            req.params = req_params
            req.params["timestamp"] = Time.current.to_i
          end
          response.body
        end

      if response_json.is_a?(String)
        Rails.cache.delete(cache_key)
        self.backoff += 1
        wait_time = [self.backoff * self.backoff_factor, self.backoff_max].min
        sleep(wait_time)
        Rails.logger.info("Enqueued page #{page} for retry. Waiting #{wait_time}s...")
        self.retry_pages << page
      elsif response_json.is_a?(Hash)
        self.backoff = 0
        set_total(response_json)
        add_page(page, response_json)
      end
    rescue Faraday::ConnectionFailed
      add_page(page, {})
    end

    def request_params(query, page, per_page)
      params = {}
      params["q"] = query
      params["org"] = ""
      params["date_from"] = START_DATE.strftime("%d-%m-%Y")
      params["date_to"] = Time.current.strftime("%d-%m-%Y")
      params["from"] = per_page * (page - 1)
      params["site"] = "nl"
      params
    end

    def set_total(response, per_page: ITEMS_RECEIVED_PER_PAGE)
      return if response.blank?

      self.total_results ||= response.dig("hits", "total").presence || 0
      self.total_pages ||= (self.total_results / per_page.to_f).ceil
    end

    def add_page(page, response)
      return unless response.present?

      matches = response.dig("hits", "hits").presence || []
      self.result_pages[page] = matches.map { |hit| hit["_source"] }
    end

    def external_registry_bikes_from(result_pages:)
      result_pages
        .map { |result| VerlorenOfGevondenResult.new(result) }
        .select(&:bike?)
        .map(&:to_external_registry_bike)
        .each(&:save)
        .select(&:persisted?)
    end
  end
end
