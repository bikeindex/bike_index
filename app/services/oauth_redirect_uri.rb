module OauthRedirectUri
  extend Functionable

  # Custom schemes (native apps) and loopback (RFC 8252) never reach the network
  def cleartext?(redirect_uri)
    uri = URI.parse(redirect_uri.to_s)
    uri.scheme == "http" && !%w[localhost 127.0.0.1 ::1].include?(uri.hostname&.downcase)
  rescue URI::InvalidURIError
    false
  end
end
