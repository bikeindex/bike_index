module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ControllerHelpers
    before_filter :authenticate_user

    private

    # Overriding doorkeepers default, so we can add partner to the session
    def authenticate_resource_owner!
      session[:partner] = params[:partner] if params[:partner].present?
      super
    end
  end
end
