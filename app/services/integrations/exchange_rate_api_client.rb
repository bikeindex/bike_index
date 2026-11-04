# frozen_string_literal: true

module Integrations
  class ExchangeRateAPIClient
    BASE_URL = ENV.fetch("EXCHANGE_RATE_API_BASE_URL", "https://api.exchangeratesapi.io")
    API_KEY = ENV["EXCHANGE_RATE_API_KEY"]
    # Our plan rejects any other base with base_currency_access_restricted
    API_BASE_ISO = "EUR"

    attr_accessor :base_iso, :base_url, :cache_key

    def initialize(base_iso = "USD")
      self.base_iso = base_iso
      self.base_url = BASE_URL
      self.cache_key = ["exchange_rate", Date.current].join("::")
    end

    def latest
      payload = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
        resp = conn.get("latest") { |req|
          req.params = {"base" => API_BASE_ISO, :access_key => API_KEY}
        }

        raise(StandardError, resp.body) unless resp.status == 200 && resp.body.is_a?(Hash)

        resp.body.with_indifferent_access
      end

      rates = payload.fetch(:rates)
      base_rate = rates.fetch(base_iso).to_f
      payload.merge(base: base_iso, rates: rates.transform_values { it / base_rate })
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
end
