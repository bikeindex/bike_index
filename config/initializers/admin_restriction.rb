class AdminRestriction
  def self.matches?(req)
    return false unless (cookie = req.cookie_jar["auth"])

    auth =
      Rack::Session::Cookie::Base64::JSON.new.decode(cookie) ||
      Rack::Session::Cookie::Base64::Marshal.new.decode(cookie)

    user = User.from_auth(auth)

    user&.superuser?
  end
end
