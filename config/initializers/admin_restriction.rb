class AdminRestriction
  def self.matches?(req)
    return false unless req.cookies["auth"].present?

    auth = Rack::Session::Cookie::Base64::Marshal.new.decode(req.cookies["auth"])
    user = User.from_auth(auth)

    user&.superuser?
  end
end
