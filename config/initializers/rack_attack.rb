# frozen_string_literal: true

class Rack::Attack
  MAX_REQUESTS_PER_TWENTY = ENV.fetch("RACK_ATTACK_MAX_LIMIT", 30).to_i
  API_MAX_REQUESTS = ENV.fetch("RACK_ATTACK_API_MAX_LIMIT", 150).to_i
  CSP_REPORTS_MAX_REQUESTS = ENV.fetch("RACK_ATTACK_CSP_LIMIT", MAX_REQUESTS_PER_TWENTY).to_i

  # Email-first login enters auth at /session/identify (account + org lookup) before
  # /session (password), so both share the sign-in throttles below.
  SIGN_IN_PATHS = ["/session", "/session/identify"].freeze
  CSP_REPORTS_PATH = "/csp_reports"
  DIRECT_UPLOADS_PATH = "/rails/active_storage/direct_uploads"
  REGISTER_DIRECT_UPLOADS_PATH = "/register/direct_uploads"
  DIRECT_UPLOAD_MAX = ENV.fetch("RACK_ATTACK_DIRECT_UPLOAD_LIMIT", 20).to_i
  REGISTER_DIRECT_UPLOAD_MAX = ENV.fetch("RACK_ATTACK_REGISTER_DIRECT_UPLOAD_LIMIT", 60).to_i

  SENSITIVE_AUTH_PATHS = %w[
    /session/create_magic_link
    /session/sign_in_with_magic_link
    /users/send_password_reset_email
    /users/update_password_with_reset_token
    /users/resend_confirmation_email
  ].freeze

  SKIP_THROTTLE_PREFIXES = %w[/api /oauth /assets].freeze
  API_PATH_PREFIXES = %w[/api /oauth].freeze

  # Search autocomplete and kind-count endpoints are XHR/data calls fired
  # repeatedly during normal searching (per-keystroke autocomplete, kind counts) -
  # not page navigations. Throttle them like the API (generous per-IP budget)
  # rather than against the strict per-page limit, which active searching trips.
  SEARCH_DATA_PREFIXES = %w[/search/combobox /search/marketplace/counts].freeze

  cache.store = ActiveSupport::Cache::RedisCacheStore.new(
    url: Bikeindex::Application.config.redis_rack_attack_url
  )

  # API, OAuth, and search data (autocomplete/counts): 150 per 30 seconds per IP
  throttle("api/ip", limit: API_MAX_REQUESTS, period: 30.seconds) do |request|
    request.ip if request.path.start_with?(*API_PATH_PREFIXES, *SEARCH_DATA_PREFIXES)
  end

  # Global rate limit per IP (non-API, non-OAuth, non-assets, non-search-data, non-csp-reports)
  throttle("requests/ip", limit: MAX_REQUESTS_PER_TWENTY, period: 20.seconds) do |request|
    request.ip unless request.path.start_with?(*SKIP_THROTTLE_PREFIXES, *SEARCH_DATA_PREFIXES, CSP_REPORTS_PATH)
  end

  # CSP violation reports are browser-automatic and filtered server-side, so a
  # flood is harmless to drop. Cap them on their own per-IP bucket, kept out of
  # the global throttle so reports can't consume a user's navigation budget.
  throttle("csp_reports/ip", limit: CSP_REPORTS_MAX_REQUESTS, period: 1.minute) do |request|
    request.ip if request.post? && request.path == CSP_REPORTS_PATH
  end

  # Sign-in: 10 per minute per IP
  throttle("sign_in/ip", limit: 10, period: 1.minute) do |request|
    request.ip if request.post? && SIGN_IN_PATHS.include?(request.path)
  end

  # Sign-in: 5 per 20 seconds per email (protects individual accounts)
  # Note: a malicious user could intentionally throttle logins for
  # another user, but this is uncommon in practice.
  throttle("sign_in/email", limit: 5, period: 20.seconds) do |request|
    if request.post? && SIGN_IN_PATHS.include?(request.path)
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

  # Each direct upload hands out a presigned URL to write into our bucket. Both endpoints
  # verify who's asking in the app - signed in for one, a registration token for the other -
  # so these only cap how fast one address can ask. The anonymous one is hourly rather than
  # per-minute because a shop's embed form registers bike after bike from the one address.
  throttle("direct_uploads/ip", limit: DIRECT_UPLOAD_MAX, period: 1.minute) do |request|
    request.ip if request.post? && request.path == DIRECT_UPLOADS_PATH
  end

  throttle("register_direct_uploads/ip", limit: REGISTER_DIRECT_UPLOAD_MAX, period: 1.hour) do |request|
    request.ip if request.post? && request.path == REGISTER_DIRECT_UPLOADS_PATH
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
