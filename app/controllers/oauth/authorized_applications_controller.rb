class Oauth::AuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
  include AuthenticationHelper
  helper_method :current_user, :current_organization, :user_root_url
  before_filter :authenticate_user!
  before_filter :set_current_user_instance

  def set_current_user_instance
    @current_user = current_user if current_user.present?
  end

end