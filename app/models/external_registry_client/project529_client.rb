# frozen_string_literal: true

class ExternalRegistryClient::Project529Client < ExternalRegistryClient
  BASE_URL = ENV.fetch("PROJECT_529_BASE_URL", "https://project529.com/garage")

  def initialize(base_url: BASE_URL)
    self.base_url = base_url
  end

  def get_oauth_token
    response = conn.post("oauth/token") { |req|
      req.headers["Content-Type"] = "application/json"
      req.params = {
        grant_type: "refresh_token",
        client_id: credentials.app_id,
        refresh_token: credentials.refresh_token
      }
    }

    unless response.status == 200 && response.body.is_a?(Hash)
      raise Project529ClientError, response.body
    end

    response.body.with_indifferent_access
  end

  def bikes(page: 1, per_page: 10, updated_at: nil)
    # Exclude non-bikes, any bikes without serial numbers, since we won't be
    # searching for these.
    bike_attrs =
      request_bikes(page, per_page, updated_at)
        .map { |attrs| ExternalRegistryBike::Project529Bike.build_from_api_response(attrs) }
        .compact

    saved_bikes = bike_attrs.each(&:save).select(&:persisted?)

    ExternalRegistryBike.where(id: saved_bikes.map(&:id))
  rescue Faraday::TimeoutError
    ExternalRegistryBike.none
  end

  def request_bikes(page, per_page, updated_at = nil)
    credentials.set_access_token unless credentials.access_token_valid?
    # Always parse, because we need to strftime
    updated_at = BinxUtils::TimeParser.parse(updated_at.presence || Time.current - 20.days)

    req_params = {
      updated_at: updated_at.strftime("%Y-%m-%d"),
      page: page,
      per_page: per_page
    }

    cache_key = [self.class.to_s, __method__.to_s, req_params]

    cached_response =
      Rails.cache.fetch(cache_key, expires_in: TTL_HOURS) {
        response = conn.get("services/v1/bikes") { |req|
          req.headers["Content-Type"] = "application/json"
          req.params = req_params.merge(access_token: credentials.access_token)
        }

        {status: response.status, body: response.body}
      }

    if cached_response[:status] == 200 && cached_response[:body].is_a?(Hash)
      cached_response[:body].with_indifferent_access[:bikes]
    else
      raise Project529ClientError, cached_response
    end
  end

  class Project529ClientError < StandardError; end

  class Project529ClientInvalidCredentialsError < Project529ClientError; end
end
