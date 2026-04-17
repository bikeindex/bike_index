class Integrations::CloudflareTurnstile
  SITE_KEY = ENV["CLOUDFLARE_TURNSTILE_SITE_KEY"]
  SECRET_KEY = ENV["CLOUDFLARE_TURNSTILE_SECRET_KEY"]
  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  def self.configured?
    SITE_KEY.present? && SECRET_KEY.present?
  end

  def self.verify(token, ip: nil)
    return true unless configured?
    return false if token.blank?

    response = Faraday.post(VERIFY_URL) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = URI.encode_www_form({secret: SECRET_KEY, response: token, remoteip: ip}.compact)
    end
    JSON.parse(response.body)["success"] == true
  rescue Faraday::Error, JSON::ParserError
    false
  end
end
