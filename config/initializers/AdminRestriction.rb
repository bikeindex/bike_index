class AdminRestriction
  def self.matches?(request)
    user_id = request.env['rack.session'][:user_id]
    user = User.find_by_id(user_id)
    return user && user.superuser?
    # unless current_user.present? and current_user.superuser?
    #   flash[:error] = "Gotta be an admin. Srys"
    #   redirect_to user_home_url(:subdomain => false) and return
    # end
  end
end