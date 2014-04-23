class AdminRestriction
  def self.matches?(request)
    user_id = request.env['rack.session'][:user_id]
    user = User.find_by_id(user_id)
    return user && user.superuser?
  end
end