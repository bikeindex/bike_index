# frozen_string_literal: true

class ExchangeRateAPIClient
  attr_accessor :base_iso, :base_url, :cache_key

  BASE_URL = ENV.fetch("EXCHANGE_RATE_API_BASE_URL", "https://api.exchangeratesapi.io")
  API_KEY = ENV["EXCHANGE_RATE_API_KEY"]

  def initialize(base_iso = "USD")
    self.base_iso = base_iso
    self.base_url = BASE_URL
    self.cache_key = ["exchange_rate", Date.current].join("::")
  end

  def latest
    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      resp = conn.get("latest") { |req|
        req.params = {"base" => base_iso, :access_key => API_KEY}
      }

      unless resp.status == 200 && resp.body.is_a?(Hash)
        raise ExchangeRateAPIError, resp.body
      end

      resp.body.with_indifferent_access
    end
  end

  private

  def conn
    @conn ||= Faraday.new(url: base_url) { |conn|
      conn.response :json, content_type: /\bjson$/
      # if Rails.env.development?
      #   conn.use Faraday::RequestResponseLogger::Middleware,
      #     logger_level: :info,
      #     logger: Rails.logger
      # end
      conn.adapter Faraday.default_adapter
      conn.options.timeout = 5
    }
  end
end

class ExchangeRateAPIError < StandardError; end
