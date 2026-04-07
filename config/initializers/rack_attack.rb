# frozen_string_literal: true

class Rack::Attack
  MAX_REQUESTS_PER_TWENTY = ENV.fetch("RACK_ATTACK_MAX_LIMIT", 30).to_i
  API_MAX_REQUESTS = ENV.fetch("RACK_ATTACK_API_MAX_LIMIT", 150).to_i

  SIGN_IN_PATH = "/session"

  SENSITIVE_AUTH_PATHS = %w[
    /session/create_magic_link
    /session/sign_in_with_magic_link
    /users/send_password_reset_email
    /users/update_password_with_reset_token
    /users/resend_confirmation_email
  ].freeze

  SKIP_THROTTLE_PREFIXES = %w[/api /oauth /assets].freeze
  API_PATH_PREFIXES = %w[/api /oauth].freeze

  cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: Bikeindex::Application.config.redis_rack_attack_url
  )

  # API and OAuth: 150 per 30 seconds per IP
  throttle("api/ip", limit: API_MAX_REQUESTS, period: 30.seconds) do |request|
    request.ip if request.path.start_with?(*API_PATH_PREFIXES)
  end

  # Global rate limit per IP (non-API, non-OAuth, non-assets)
  throttle("requests/ip", limit: MAX_REQUESTS_PER_TWENTY, period: 20.seconds) do |request|
    request.ip unless request.path.start_with?(*SKIP_THROTTLE_PREFIXES)
  end

  # Sign-in: 10 per minute per IP
  throttle("sign_in/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && request.path == SIGN_IN_PATH
  end

  # Sign-in: 5 per 20 seconds per email (protects individual accounts)
  # Note: a malicious user could intentionally throttle logins for
  # another user, but this is uncommon in practice.
  throttle("sign_in/email", limit: 5, period: 20.seconds) do |request|
    if request.post? && request.path == SIGN_IN_PATH
      EmailNormalizer.normalize(request.params.dig("session", "email"))
    end
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

  # Account password update: 5 per minute per IP
  throttle("account_update/ip", limit: 5, period: 1.minute) do |request|
    request.ip if request.patch? && request.path == "/my_account"
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = (match_data || {})[:period]
    headers = {"retry-after" => retry_after.to_s}

    if request.env["HTTP_ACCEPT"]&.include?("json") || request.path.start_with?("/api")
      headers["content-type"] = "application/json"
      body = {error: "Too Many Requests"}.to_json
    else
      headers["content-type"] = "text/plain"
      body = "Too Many Requests"
    end

    [429, headers, [body]]
  end
end
