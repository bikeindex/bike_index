module Oauth
  class AuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
    include AuthenticationHelper
    include ControllerHelpers
    helper_method :current_user, :current_organization, :user_root_url, :controller_namespace,
                  :page_id, :remove_session, :revised_layout_enabled?, :forwarded_ip_address
    before_filter :authenticate_user
    before_filter :set_current_user_instance

    def set_current_user_instance
      @current_user = current_user if current_user.present?
    end
  end
end
