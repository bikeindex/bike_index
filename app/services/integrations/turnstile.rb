module Integrations
  module Turnstile
    extend Functionable

    SITE_KEY = ENV["TURNSTILE_SITE_KEY"]
    SECRET_KEY = ENV["TURNSTILE_SECRET_KEY"]
    RESPONSE_PARAM = "cf-turnstile-response"

    def enabled? = SITE_KEY.present? && SECRET_KEY.present?

    # Unconfigured is unchallenged, so a missing key can't lock anyone out of registering
    def challenge?(email) = enabled? && Ownership.risky_email?(email)

    # The token is single use - a form re-rendered for some other error has to mint a
    # fresh one, which is why the widget renders on every challenged submission
    def verified?(token, remote_ip: nil)
      return false if token.blank?

      response = connection.post("/turnstile/v0/siteverify") do |req|
        req.body = {secret: SECRET_KEY, response: token, remoteip: remote_ip}.compact.to_json
      end
      JSON.parse(response.body)["success"]
    rescue Faraday::Error, JSON::ParserError => e
      # Cloudflare being unreachable shouldn't take registration down with it
      Honeybadger.notify(e) if Rails.env.production?
      true
    end

    #
    # private below here
    #

    def connection
      Faraday.new(url: "https://challenges.cloudflare.com") do |conn|
        conn.headers["Content-Type"] = "application/json"
        conn.adapter Faraday.default_adapter
      end
    end

    conceal :connection
  end
end
