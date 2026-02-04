class DeveloperRestriction
  def self.matches?(req)
    cookie = req.cookies["auth"]
    return false unless cookie.present?

    auth = Rack::Session::Cookie::Base64::JSON.new.decode(cookie)

    # With signed cookies (in production), there is another layer of encoding
    if auth.is_a?(Hash) && auth["_rails"].present?
      auth = JSON.parse(Base64.decode64(auth.dig("_rails", "message")))
    end

    user = User.from_auth(auth)

    user&.developer?
  end
end
