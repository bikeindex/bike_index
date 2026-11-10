# frozen_string_literal: true

module Admin
  # Admin pages that local agents/tooling reach with the admin app's OAuth token.
  # Only the actions a controller names in token_accessible take one - the token's user
  # is a superuser, so every other action turns it away rather than trusting it
  module TokenAccessible
    extend ActiveSupport::Concern
    include API::TokenAuthenticatable

    included do
      class_attribute :token_actions, default: []
      # Token requests carry no CSRF token, they authenticate with the token alone
      skip_before_action :verify_authenticity_token, if: :token_action_request?
    end

    class_methods do
      def token_accessible(*actions)
        self.token_actions = actions.map(&:to_s)
      end
    end

    private

    def token_action_request?
      token_request? && token_actions.include?(action_name)
    end

    # Token requests get the API's JSON errors rather than a flash + redirect
    def require_index_admin!
      return super unless token_request?
      return require_token_superuser! if token_actions.include?(action_name)

      render json: {error: "Not available with a token"}, status: :forbidden
    end
  end
end
