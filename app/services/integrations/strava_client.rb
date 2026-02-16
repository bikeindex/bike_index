# frozen_string_literal: true

class Integrations::StravaClient
  BASE_URL = "https://www.strava.com"
  API_URL = "https://www.strava.com/api/v3"
  DEFAULT_SCOPE = "read,activity:read_all,profile:read_all"
  STRAVA_KEY = ENV["STRAVA_KEY"]
  STRAVA_SECRET = ENV["STRAVA_SECRET"]
  STRAVA_WEBHOOK_TOKEN = ENV["STRAVA_WEBHOOK_VERIFY_TOKEN"]
  ACTIVITIES_PER_PAGE = 200

  class << self
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
      get(strava_integration, "athletes/#{strava_integration.athlete_id}/stats")
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
          verify_token: STRAVA_WEBHOOK_TOKEN
        }
      end
    end

    def view_webhook_subscriptions
      oauth_connection.get("api/v3/push_subscriptions") do |req|
        req.params = {client_id: STRAVA_KEY, client_secret: STRAVA_SECRET}
      end
    end

    def proxy_request(strava_integration, path, method: "GET")
      raise ArgumentError, "Invalid proxy path" if path.blank? || path.match?(%r{://|\A//})
      path = path.delete_prefix("/")
      ensure_valid_token!(strava_integration)
      conn = api_connection(strava_integration)
      case method.to_s.upcase
      when "POST" then conn.post(path)
      when "PUT" then conn.put(path)
      else conn.get(path)
      end
    end

    def delete_webhook_subscription(subscription_id)
      oauth_connection.delete("api/v3/push_subscriptions/#{subscription_id}") do |req|
        req.body = {client_id: STRAVA_KEY, client_secret: STRAVA_SECRET}
      end
    end

    def ensure_valid_token!(strava_integration)
      return if strava_integration.token_expires_at.present? && strava_integration.token_expires_at > Time.current

      conn = oauth_connection
      resp = conn.post("oauth/token") do |req|
        req.body = {
          client_id: STRAVA_KEY,
          client_secret: STRAVA_SECRET,
          grant_type: "refresh_token",
          refresh_token: strava_integration.refresh_token
        }
      end
      return unless resp.success?

      data = resp.body
      strava_integration.update(
        access_token: data["access_token"],
        refresh_token: data["refresh_token"],
        token_expires_at: Time.at(data["expires_at"])
      )
    end

    private

    def get(strava_integration, path, params = {})
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
  end
end
