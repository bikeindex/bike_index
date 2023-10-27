class AdminRestriction
  def self.matches?(req)
    return false unless (cookie = req.cookie_jar["auth"])

    raise cookie

    pp "cookie: #{cookie}"
    auth = JSON.parse(Base64.decode64(cookie))
    user = User.from_auth(auth)

    user&.superuser?
  end
end
