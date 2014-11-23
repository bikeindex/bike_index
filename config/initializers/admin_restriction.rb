class AdminRestriction
  def self.matches?(req)
    auth =  Rack::Session::Cookie::Base64::Marshal.new.decode(req.cookies["auth"])
    user = User.from_auth(auth)
    return user && user.superuser?
  end
end