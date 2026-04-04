# frozen_string_literal: true

class Rack::Attack
  MAX_REQUESTS_PER_TWENTY = ENV.fetch("RACK_ATTACK_MAX_LIMIT", 30).to_i

  SIGN_IN_PATH = "/session"

  SENSITIVE_AUTH_PATHS = %w[
    /session/create_magic_link
    /session/sign_in_with_magic_link
    /users/send_password_reset_email
    /users/update_password_with_reset_token
    /users/resend_confirmation_email
  ].freeze

  cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: Bikeindex::Application.config.redis_rack_attack_url
  )

  # Global rate limit per IP
  throttle("requests/ip", limit: MAX_REQUESTS_PER_TWENTY, period: 20.seconds) do |request|
    request.ip
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

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    retry_after = (match_data || {})[:period]
    [429, {"content-type" => "text/plain", "retry-after" => retry_after.to_s}, ["Too Many Requests"]]
  end
end
