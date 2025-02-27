module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ControllerHelpers
    before_action :authenticate_user_permit_unconfirmed_scope

    private

    def authenticate_user_permit_unconfirmed_scope
      unless params[:scope].to_s[/unconfirmed/i].present? && unconfirmed_current_user.present?
        store_return_and_authenticate_user
      end
    end

    # Overriding doorkeepers default, so we can add partner to the session
    def authenticate_resource_owner!
      if params[:partner].present?
        session[:partner] = params[:partner]
        session[:company] = params[:company] # Only set company when partner is present
      end
      super
    end
  end
end
