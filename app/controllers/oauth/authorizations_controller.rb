module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    include ControllerHelpers

    before_action :authenticate_user_permit_unconfirmed_scope
    helper_method :pre_auth_hidden_fields

    private

    # #create rebuilds pre_auth from what the consent form posts, so a field the form
    # omits is dropped from the grant
    def pre_auth_hidden_fields
      custom_attributes = pre_auth.custom_access_token_attributes.symbolize_keys
      pre_auth_param_fields.index_with do |field|
        (field == :client_id) ? pre_auth.client.uid : custom_attributes.fetch(field) { pre_auth.public_send(field) }
      end
    end

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
