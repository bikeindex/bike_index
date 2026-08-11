# frozen_string_literal: true

module API
  # OAuth bearer-token lookup and user authorization for plain Rails controllers,
  # both the API endpoints and the admin pages local agents/tooling reach.
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    ADMIN_DOORKEEPER_APP_ID = ENV.fetch("ADMIN_DOORKEEPER_APP_ID", 54).to_i

    private

    def current_user
      return super unless token_request?

      authorize_user(doorkeeper_token)[:user]
    end

    # doorkeeper_token is nil for a revoked token, so branch on the string as presented -
    # that caller gets the API's 401 rather than a redirect to sign in. Every current_user
    # call asks, which an admin page render does ~10 times
    def token_request?
      return @token_request if defined?(@token_request)

      @token_request = Doorkeeper::OAuth::Token
        .from_request(request, *Doorkeeper.configuration.access_token_methods).present?
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

    def require_token_superuser!
      auth = authorize_user(doorkeeper_token)
      return render(json: {error: auth[:error]}, status: auth[:status]) if auth[:error]
      return if auth[:user].superuser?(controller_name:, action_name:)

      render json: {error: "Not permitted"}, status: 403
    end

    # The admin app, unless overridden by a controller serving a different OAuth application
    def authorized_app?(access_token)
      access_token.application_id == ADMIN_DOORKEEPER_APP_ID
    end
  end
end
