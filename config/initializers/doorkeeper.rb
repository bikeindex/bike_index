OAUTH_SCOPES = [:public, :read_user, :read_bikes, :write_user, :write_bikes, :read_bikewise, :write_bikewise, :read_organization_membership]
OAUTH_SCOPES_S = OAUTH_SCOPES.join(' ')
if Rails.env.development?
  ENV['V2_ACCESSOR_ID'] = (User.fuzzy_email_find('api@example.com') || User.first).id.to_s
end
Doorkeeper.configure do
  # Change the ORM that doorkeeper will use.
  orm :active_record

  # This block will be called to check whether the resource owner is authenticated or not.
  resource_owner_authenticator do
    @user ||= User.from_auth(cookies.signed[:auth])
    unless @user
      session[:return_to] = request.fullpath
      redirect_to(new_session_url)
    end

    @user
  end

  # If you want to restrict access to the web interface for adding oauth authorized applications, you need to declare the block below.
  # admin_authenticator do
  #   # Put your admin authentication logic here.
  #   # Example implementation:
  #   Admin.find_by_id(session[:admin_id]) || redirect_to(new_admin_session_url)
  # end

  # Authorization Code expiration time (default 10 minutes).
  # authorization_code_expires_in 10.minutes

  # Access token expiration time (default 2 hours).
  access_token_expires_in 1.hours

  # Reuse access token for the same resource owner within an application (disabled by default)
  # Rationale: https://github.com/doorkeeper-gem/doorkeeper/issues/383
  # reuse_access_token

  # Issue access tokens with refresh token (disabled by default)
  use_refresh_token

  # Provide support for an owner to be assigned to each registered application (disabled by default)
  enable_application_owner :confirmation => true

  # Define access token scopes for your provider
  # default_scopes  :public
  optional_scopes :public, :read_user, :write_user, :read_bikes, :write_bikes, :read_bikewise, :write_bikewise, :read_organization_membership

  # Change the way client credentials are retrieved from the request object.
  # By default it retrieves first from the `HTTP_AUTHORIZATION` header, then
  # falls back to the `:client_id` and `:client_secret` params from the `params` object.
  # Check out the wiki for more information on customization
  # client_credentials :from_basic, :from_params

  # Change the way access token is authenticated from the request object.
  # By default it retrieves first from the `HTTP_AUTHORIZATION` header, then
  # falls back to the `:access_token` or `:bearer_token` params from the `params` object.
  # Check out the wiki for more information on customization
  # access_token_methods :from_bearer_authorization, :from_access_token_param, :from_bearer_param

  # Change the native redirect uri for client apps
  # When clients register with the following redirect uri, they won't be redirected to any server and the authorization code will be displayed within the provider
  # The value can be any string. Use nil to disable this feature. When disabled, clients must provide a valid URL
  # (Similar behaviour: https://developers.google.com/accounts/docs/OAuth2InstalledApp#choosingredirecturi)
  #
  # native_redirect_uri 'urn:ietf:wg:oauth:2.0:oob'

  # Specify what grant flows are enabled in array of Strings. The valid
  # strings and the flows they enable are:
  #
  # "authorization_code" => Authorization Code Grant Flow
  # "implicit"           => Implicit Grant Flow
  # "password"           => Resource Owner Password Credentials Grant Flow
  # "client_credentials" => Client Credentials Grant Flow
  #
  # If not specified, Doorkeeper enables all the four grant flows.
  #
  grant_flows %w(authorization_code implicit password client_credentials)

  # Under some circumstances you might want to have applications auto-approved,
  # so that the user skips the authorization step.
  # For example if dealing with trusted a application.
  skip_authorization do |resource_owner, client|
    client.application.is_internal
  end

  # WWW-Authenticate Realm (default "Doorkeeper").
  # realm "Doorkeeper"

  # Allow dynamic query parameters (disabled by default)
  # Some applications require dynamic query parameters on their request_uri
  # set to true if you want this to be allowed
  # wildcard_redirect_uri false
end