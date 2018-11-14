module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ControllerHelpers
    before_filter :authenticate_user

    private
    # Overriding doorkeepers default, so we can set the session partner session
    def authenticate_resource_owner!
      session[:partner] = params[:partner] if params[:partner].present?
      current_resource_owner
    end
  end
end