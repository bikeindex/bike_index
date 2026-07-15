# frozen_string_literal: true

module API
  # OAuth bearer-token lookup and user authorization for plain Rails controllers
  # under the API namespace.
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    private

    def current_user
      authorize_user(doorkeeper_token)[:user]
    end

    # Returns {user:} when the token authorizes a user, otherwise {error:, status:}
    def authorize_user(access_token)
      return @authorize_user if defined?(@authorize_user)

      @authorize_user = if !access_token&.accessible?
        {status: 401, error: "OAuth token required"}
      elsif !authorized_app?(access_token)
        {status: 403, error: "Unauthorized application"}
      elsif (user = User.find_by(id: access_token.resource_owner_id))
        {user:}
      else
        {status: 401, error: "User not found"}
      end
    end

    # Overridden by controllers that restrict access to a specific OAuth application
    def authorized_app?(_access_token)
      true
    end

    def doorkeeper_token
      @doorkeeper_token ||= Doorkeeper::OAuth::Token.authenticate(
        request, *Doorkeeper.configuration.access_token_methods
      )
    end
  end
end
