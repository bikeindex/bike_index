# frozen_string_literal: true

class ExternalRegistryClient::Project529Client < ExternalRegistryClient
  BASE_URL = ENV.fetch("PROJECT_529_BASE_URL", "https://project529.com/garage")

  def initialize(base_url: BASE_URL)
    self.base_url = base_url
  end

  def get_oauth_token
    response = conn.post("oauth/token") do |req|
      req.headers["Content-Type"] = "application/json"
      req.params = {
        grant_type: "refresh_token",
        client_id: credentials.app_id,
        refresh_token: credentials.refresh_token,
      }
    end

    unless response.status == 200 && response.body.is_a?(Hash)
      raise Project529ClientError, response.body
    end

    response.body.with_indifferent_access
  end

  def bikes(updated_at: nil, page: 1, per_page: 10)
    credentials.set_access_token unless credentials.access_token_valid?

    req_params = {
      updated_at: (updated_at.presence || Time.current - 20.days).strftime("%Y-%m-%d"),
      page: page,
      per_page: per_page,
    }

    cache_key = [self.class.to_s, __method__.to_s, req_params]

    response =
      Rails.cache.fetch(cache_key, expires_in: TTL_HOURS) do
        response = conn.get("services/v1/bikes") do |req|
          req.headers["Content-Type"] = "application/json"
          req.params = req_params.merge(access_token: credentials.access_token)
        end

        { status: response.status, body: response.body.with_indifferent_access }
      end

    unless response[:status] == 200 && response[:body].is_a?(Hash)
      raise Project529ClientError, response
    end

    results =
      response
        .dig(:body, :bikes)
        .map { |attrs| ExternalRegistryBike::Project529Bike.build_from_api_response(attrs) }
        .compact
        .each(&:save)
        .select(&:persisted?)
    ExternalRegistryBike.where(id: results.map(&:id))
  rescue Faraday::TimeoutError
    ExternalRegistryBike.none
  end

  class Project529ClientError < StandardError; end
  class Project529ClientInvalidCredentialsError < Project529ClientError; end
end
