module Integrations
  module Turnstile
    extend Functionable

    SITE_KEY = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
    SECRET_KEY = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
    RESPONSE_PARAM = "cf-turnstile-response"
    TIMEOUT_SECONDS = 5
    # Both keys, since half-configured renders a widget nothing verifies - and an env
    # to switch the challenge off without pulling them
    ENABLED = (SITE_KEY.present? && SECRET_KEY.present? &&
      ENV["CLOUDFLARE_TURNSTILE_DISABLE"] != "true").freeze

    # Unchallenged while it's off, so a missing key can't lock anyone out of registering
    def challenge?(email, user: nil)
      return false unless ENABLED

      EmailDomain.risky_email?(email) && !own_confirmed_email?(email, user)
    end

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

    # What the challenge protects is a confirmation email to an unproven address, which a
    # signed-in rider registering to their own already answered. Their unconfirmed addresses
    # aren't proven, and someone else's risky address is asked whoever is signed in
    def own_confirmed_email?(email, user)
      return false if user.blank?

      user.confirmed_emails.include?(EmailNormalizer.normalize(email))
    end

    def connection
      Faraday.new(url: "https://challenges.cloudflare.com") do |conn|
        conn.headers["Content-Type"] = "application/json"
        # Registration blocks on this, so it gives up well inside rack-timeout's 30s
        conn.options.timeout = TIMEOUT_SECONDS
        conn.adapter Faraday.default_adapter
      end
    end

    conceal :own_confirmed_email?, :connection
  end
end
