class AdminRestriction
  def self.matches?(request)
    user = User.find_by_auth_token!(request.env['rack.request.cookie_hash']['auth_token']) if request.env['rack.request.cookie_hash']['auth_token']
    return user && user.superuser?
  end
end