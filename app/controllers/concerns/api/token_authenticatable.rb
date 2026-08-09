# frozen_string_literal: true

module API
  # OAuth bearer-token lookup and user authorization for plain Rails controllers,
  # both the API endpoints and the admin pages local agents/tooling reach.
  module TokenAuthenticatable
    extend ActiveSupport::Concern

    ADMIN_DOORKEEPER_APP_ID = ENV.fetch("ADMIN_DOORKEEPER_APP_ID", 54).to_i

    private

    # A token identifies the user when one is passed, otherwise the signed in user
    def current_user
      return super if doorkeeper_token.blank?

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

    # Renders the JSON error unless the token belongs to a superuser for this controller
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

    # Memoizes the miss too - every admin page view asks, and most have no token
    def doorkeeper_token
      return @doorkeeper_token if defined?(@doorkeeper_token)

      @doorkeeper_token = Doorkeeper::OAuth::Token.authenticate(
        request, *Doorkeeper.configuration.access_token_methods
      )
    end
  end
end
