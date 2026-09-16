module Integrations
  module Turnstile
    extend Functionable

    SITE_KEY = ENV["TURNSTILE_SITE_KEY"]
    SECRET_KEY = ENV["TURNSTILE_SECRET_KEY"]
    RESPONSE_PARAM = "cf-turnstile-response"
    TIMEOUT_SECONDS = 5
    SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js"

    def enabled? = SITE_KEY.present? && SECRET_KEY.present?

    # Half-configured renders a widget nothing verifies, so the key is only worth
    # rendering with once the secret is there to check it against
    def site_key = (SITE_KEY if enabled?)

    # Unconfigured is unchallenged, so a missing key can't lock anyone out of registering
    def challenge?(email) = enabled? && EmailDomain.risky_email?(email)

    # The token is single use, so a re-rendered form has to mint a fresh one
    def verified?(token, remote_ip: nil)
      return false if token.blank?

      response = connection.post("/turnstile/v0/siteverify") do |req|
        req.body = {secret: SECRET_KEY, response: token, remoteip: remote_ip}.compact.to_json
      end
      JSON.parse(response.body)["success"]
    end

    #
    # private below here
    #

    def connection
      Faraday.new(url: "https://challenges.cloudflare.com") do |conn|
        conn.headers["Content-Type"] = "application/json"
        # Registration blocks on this, so it gives up well inside rack-timeout's 30s
        conn.options.timeout = TIMEOUT_SECONDS
        conn.adapter Faraday.default_adapter
      end
    end

    conceal :connection
  end
end
