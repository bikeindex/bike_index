# frozen_string_literal: true

class ExchangeRateApiClient
  attr_accessor :base_iso, :base_url

  BASE_URL = ENV.fetch("EXCHANGE_RATE_API_BASE_URL", "https://api.exchangeratesapi.io")

  def initialize(base_iso="USD")
    self.base_iso = base_iso
    self.base_url = BASE_URL
  end

  def latest
    resp = conn.get("latest") do |req|
      req.params = {"base" => base_iso}
    end

    unless resp.status == 200 && resp.body.is_a?(Hash)
      raise ExchangeRateApiError, resp.body
    end

    resp.body.with_indifferent_access
  end

  private

  def conn
    @conn ||= Faraday.new(url: base_url) do |conn|
      conn.response :json, content_type: /\bjson$/
      conn.use Faraday::RequestResponseLogger::Middleware,
               logger_level: :info,
               logger: Rails.logger if Rails.env.development?
      conn.adapter Faraday.default_adapter
      conn.options.timeout = 5
    end
  end
end

class ExchangeRateApiError < StandardError; end
