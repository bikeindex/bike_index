# frozen_string_literal: true

class Integrations::ExchangeRateAPIClient
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

      raise(StandardError, resp.body) unless resp.status == 200 && resp.body.is_a?(Hash)

      resp.body.with_indifferent_access
    end
  end

  private

  def conn
    @conn ||= Faraday.new(url: base_url) do |con|
      con.response :json, content_type: /\bjson$/
      con.adapter Faraday.default_adapter
      con.options.timeout = 5
    end
  end
end
