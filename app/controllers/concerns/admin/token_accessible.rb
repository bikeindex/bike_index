# frozen_string_literal: true

module Admin
  # Admin pages that local agents/tooling reach with the admin app's OAuth token
  module TokenAccessible
    extend ActiveSupport::Concern
    include API::TokenAuthenticatable

    included do
      # Token requests carry no CSRF token, they authenticate with the token alone
      skip_before_action :verify_authenticity_token, if: :token_request?
    end

    private

    # Token requests get the API's JSON errors rather than a flash + redirect
    def require_index_admin!
      token_request? ? require_token_superuser! : super
    end
  end
end
