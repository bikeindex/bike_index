# frozen_string_literal: true

class Rack::Attack
  SIGN_IN_PATH = "/session"

  SENSITIVE_AUTH_PATHS = %w[
    /session/create_magic_link
    /session/sign_in_with_magic_link
    /users/send_password_reset_email
    /users/update_password_with_reset_token
    /users/resend_confirmation_email
  ].freeze

  # Use a separate Redis database to avoid key collisions with app cache.
  # Note: eviction still operates server-wide, not per database.
  REDIS_URL = begin
    uri = URI.parse(Bikeindex::Application.config.redis_cache_url)
    current_db = uri.path.delete("/").to_i
    uri.path = "/#{current_db + 1}"
    uri.to_s
  end

  cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: REDIS_URL)

  # Global rate limit per IP (replaces rack-throttle)
  throttle("requests/ip", limit: ENV.fetch("MIN_MAX_RATE", 500).to_i, period: 1.minute) do |request|
    request.ip
  end

  # Sign-in endpoints: 10 per minute per IP
  throttle("sign_in/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == SIGN_IN_PATH
  end

  # Sensitive auth endpoints: 5 per minute per IP
  throttle("sensitive_auth/ip", limit: 5, period: 1.minute) do |request|
    if request.post?
      if SENSITIVE_AUTH_PATHS.include?(request.path)
        request.ip
      elsif request.path.start_with?("/user_emails/") && request.path.end_with?("/resend_confirmation")
        request.ip
      end
    end
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = (match_data || {})[:period]
    [429, {"content-type" => "text/plain", "retry-after" => retry_after.to_s}, ["Too Many Requests"]]
  end
end
