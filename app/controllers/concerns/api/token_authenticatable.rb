# frozen_string_literal: true

module API
  # OAuth bearer-token lookup and user authorization for plain Rails controllers
  # under the API namespace.
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    private

    def current_user
      return @current_user if defined?(@current_user)

      @current_user = authorize_user(doorkeeper_token)[:user]
    end

    # Returns {user:} when the token authorizes a user, otherwise {error:, status:}
    def authorize_user(access_token)
      return {status: 401, error: "OAuth token required"} unless access_token&.accessible?
      return {status: 403, error: "Unauthorized application"} unless authorized_app?(access_token)

      user = User.find_by(id: access_token.resource_owner_id)
      return {error: "User not found", status: 401} unless user

      {user:}
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
