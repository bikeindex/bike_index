module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ControllerHelpers
    before_filter :authenticate_user_permit_unconfirmed_scope

    private

    def authenticate_user_permit_unconfirmed_scope
      authenticate_user unless params[:scope].to_s[/unconfirmed/i].present? && unconfirmed_current_user.present?
    end

    # Overriding doorkeepers default, so we can add partner to the session
    def authenticate_resource_owner!
      session[:partner] = params[:partner] if params[:partner].present?
      super
    end
  end
end
