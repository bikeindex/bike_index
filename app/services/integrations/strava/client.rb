# frozen_string_literal: true

module Integrations::Strava::Client
  extend Functionable

  BASE_URL = "https://www.strava.com"
  API_URL = "https://www.strava.com/api/v3"
  DEFAULT_SCOPE = "read,activity:read_all,profile:read_all"
  STRAVA_SEARCH_SCOPE = "#{DEFAULT_SCOPE},activity:write"
  STRAVA_KEY = ENV["STRAVA_KEY"]
  STRAVA_SECRET = ENV["STRAVA_SECRET"]
  STRAVA_WEBHOOK_TOKEN = ENV["STRAVA_WEBHOOK_VERIFY_TOKEN"]
  ACTIVITIES_PER_PAGE = 200
  RATE_LIMIT_HEADROOM = ENV.fetch("STRAVA_CLIENT_HEADROOM", 10).to_i
  FETCH_ACTIVITY_SHORT_HEADROOM = ENV.fetch("STRAVA_CLIENT_FETCH_ACTIVITY_SHORT_HEADROOM", 100).to_i
  FETCH_ACTIVITY_LONG_HEADROOM = ENV.fetch("STRAVA_CLIENT_FETCH_ACTIVITY_LONG_HEADROOM", 500).to_i
  RATE_LIMITED_RESPONSE_BODY = {
    "message" => "Rate Limit Exceeded",
    "errors" => [{"resource" => "Application", "field" => "rate limit", "code" => "exceeded"}]
  }.freeze

  def currently_rate_limited?(request_method = nil, headroom: nil, request_type: nil)
    rate_limit = StravaRequest.estimated_current_rate_limit

    if request_type&.to_sym == :fetch_activity
      (rate_limit[:read_short_limit] - rate_limit[:read_short_usage]) < FETCH_ACTIVITY_SHORT_HEADROOM ||
        (rate_limit[:read_long_limit] - rate_limit[:read_long_usage]) < FETCH_ACTIVITY_LONG_HEADROOM
    elsif request_method.blank? || request_method.upcase == "GET"
      headroom ||= RATE_LIMIT_HEADROOM
      (rate_limit[:read_short_limit] - rate_limit[:read_short_usage]) < headroom ||
        (rate_limit[:read_long_limit] - rate_limit[:read_long_usage]) < headroom
    else
      headroom ||= RATE_LIMIT_HEADROOM
      (rate_limit[:short_limit] - rate_limit[:short_usage]) < headroom ||
        (rate_limit[:long_limit] - rate_limit[:long_usage]) < headroom
    end
  end

  def exchange_token(code)
    conn = oauth_connection
    resp = conn.post("oauth/token") do |req|
      req.body = {
        client_id: STRAVA_KEY,
        client_secret: STRAVA_SECRET,
        code:,
        grant_type: "authorization_code"
      }
    end
    return nil unless resp.success?
    resp.body
  end

  def authorization_url(state:, scope: nil)
    params = {
      client_id: STRAVA_KEY,
      response_type: "code",
      redirect_uri: Rails.application.routes.url_helpers.callback_strava_integration_url,
      scope: scope || DEFAULT_SCOPE,
      approval_prompt: "auto",
      state:
    }
    "#{BASE_URL}/oauth/authorize?#{params.to_query}"
  end

  def fetch_athlete(strava_integration)
    get(strava_integration, "athlete")
  end

  def fetch_athlete_stats(strava_integration)
    get(strava_integration, "athletes/#{strava_integration.strava_id}/stats")
  end

  def list_activities(strava_integration, per_page: ACTIVITIES_PER_PAGE, page: nil, after: nil)
    params = {per_page:}
    params[:page] = page if page.present?
    params[:after] = after if after.present?
    get(strava_integration, "athlete/activities", **params)
  end

  def fetch_activity(strava_integration, strava_id)
    get(strava_integration, "activities/#{strava_id}")
  end

  def fetch_gear(strava_integration, strava_gear_id)
    get(strava_integration, "gear/#{strava_gear_id}")
  end

  def create_webhook_subscription
    oauth_connection.post("api/v3/push_subscriptions") do |req|
      req.body = {
        client_id: STRAVA_KEY,
        client_secret: STRAVA_SECRET,
        callback_url: Rails.application.routes.url_helpers.strava_webhooks_url,
        verify_token: ENV["STRAVA_WEBHOOK_VERIFY_TOKEN"]
      }
    end
  end

  def view_webhook_subscriptions
    oauth_connection.get("api/v3/push_subscriptions") do |req|
      req.params = {client_id: STRAVA_KEY, client_secret: STRAVA_SECRET}
    end
  end

  def proxy_request(strava_integration, path, method: "GET", body: nil)
    raise ArgumentError, "Invalid proxy path" if path.blank? || path.match?(%r{://|\A//|(\A|/)\.\.(/|\z)})

    path = path.delete_prefix("/")
    ensure_valid_token!(strava_integration)
    execute_proxy_request(strava_integration, path, method:, body:)
  end

  def delete_webhook_subscription(subscription_id)
    oauth_connection.delete("api/v3/push_subscriptions/#{subscription_id}") do |req|
      req.body = {client_id: STRAVA_KEY, client_secret: STRAVA_SECRET}
    end
  end

  def ensure_valid_token!(strava_integration)
    return unless strava_integration.token_expired?

    refresh_token!(strava_integration)
  end

  #
  # private below here
  #

  def refresh_token!(strava_integration)
    conn = oauth_connection
    resp = conn.post("oauth/token") do |req|
      req.body = {
        client_id: STRAVA_KEY,
        client_secret: STRAVA_SECRET,
        grant_type: "refresh_token",
        refresh_token: strava_integration.refresh_token
      }
    end
    if resp.success?
      data = resp.body
      strava_integration.update(
        access_token: data["access_token"],
        refresh_token: data["refresh_token"],
        token_expires_at: Time.at(data["expires_at"])
      )
      strava_integration.reload
    else
      strava_integration.update(status: "error")
      false
    end
  end

  def execute_proxy_request(strava_integration, path, method: "GET", body: nil)
    conn = api_connection(strava_integration)
    case method.to_s.upcase
    when "POST" then conn.post(path) { |req| req.body = body if body }
    when "PUT" then conn.put(path) { |req| req.body = body if body }
    else conn.get(path)
    end
  end

  def get(strava_integration, path, **params)
    ensure_valid_token!(strava_integration)
    api_connection(strava_integration).get(path) do |req|
      req.params = params
    end
  end

  def api_connection(strava_integration)
    Faraday.new(url: API_URL) do |conn|
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
      conn.headers["Authorization"] = "Bearer #{strava_integration.access_token}"
      conn.options.timeout = 30
    end
  end

  def oauth_connection
    Faraday.new(url: BASE_URL) do |conn|
      conn.request :url_encoded
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
      conn.options.timeout = 15
    end
  end

  conceal :refresh_token!, :execute_proxy_request, :get, :api_connection, :oauth_connection
end
