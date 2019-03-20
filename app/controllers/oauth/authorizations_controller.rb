module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ControllerHelpers
    before_filter :authenticate_user_permit_unconfirmed_scope

    private

    def authenticate_user_permit_unconfirmed_scope
      # We don't need to authenticate the users if unconfirmed users are permitted
      if params[:scope].to_s[/unconfirmed/i].present?
        return true if unconfirmed_current_user.present?
      end
      authenticate_user
    end

    # Overriding doorkeepers default, so we can add partner to the session
    def authenticate_resource_owner!
      session[:partner] = params[:partner] if params[:partner].present?
      super
    end
  end
end
