# Heavily influenced by WineBouncer - antek-drzewiecki/wine_bouncer
# To make an endpoint require a token, include an authorizations hash in the endpoint.
# authorizations: {oauth2: {scope: :public}}
# If no scope key is included, it will use default scope
module APIAuthorization
  module Errors
    class OAuthUnauthorizedError < StandardError
      attr_reader :response
      def initialize(response)
        super(response.try(:description))
        @response = response
      end
    end

    class OAuthForbiddenError < StandardError
      attr_reader :response
      def initialize(response)
        super(response.try(:description))
        @response = response
      end
    end
  end

  class OAuth2 < Grape::Middleware::Base
    require "doorkeeper/grape/authorization_decorator"

    def auth_declaration
      @endpoint_auth_declaration || {}
    end

    def endpoint_protected?
      auth_declaration.key?(:oauth2)
    end

    # Currently, only allowing one scope per endpoint.
    def endpoint_scopes
      Array(auth_declaration&.dig(:oauth2, :scope)&.to_sym)
    end

    def doorkeeper_access_token
      @doorkeeper_access_token ||= Doorkeeper::OAuth::Token.authenticate(
        Doorkeeper::Grape::AuthorizationDecorator.new(ActionDispatch::Request.new(env)),
        *Doorkeeper.configuration.access_token_methods
      )
    end

    def endpoint_client_credentials?
      auth_declaration&.dig(:oauth2, :allow_client_credentials) == true
    end

    # This is probably a client_credentials request
    def doorkeeper_access_token_no_user?
      doorkeeper_access_token&.accessible? &&
        doorkeeper_access_token.resource_owner_id.blank?
    end

    def authorized_access_token_no_user?
      endpoint_client_credentials? && doorkeeper_access_token_no_user? &&
        doorkeeper_access_token.acceptable?(endpoint_scopes)
    end

    def resource_owner
      @resource_owner ||= User.find_by_id(doorkeeper_access_token&.resource_owner_id)
    end

    def doorkeeper_authorize!
      return if doorkeeper_access_token&.acceptable?(endpoint_scopes) &&
        resource_owner.present?

      if doorkeeper_access_token.blank? || !doorkeeper_access_token.accessible?
        error = Doorkeeper::OAuth::InvalidTokenResponse.from_access_token(doorkeeper_access_token)
        raise APIAuthorization::Errors::OAuthUnauthorizedError, error
      elsif authorized_access_token_no_user?
        @resource_owner = doorkeeper_access_token.application.owner
      else
        error = if doorkeeper_access_token_no_user?
          OpenStruct.new(description: "User required; no user associated with token")
        else
          Doorkeeper::OAuth::ForbiddenTokenResponse.from_scopes(endpoint_scopes)
        end
        raise APIAuthorization::Errors::OAuthForbiddenError, error
      end
    end

    # Before grape actions happen
    def before
      @endpoint_auth_declaration = env["api.endpoint"]&.options&.dig(:route_options, :authorizations)
      return unless endpoint_protected?

      doorkeeper_authorize!
      # Assign the access_token and the user to the request object, so it can be accessed
      env["doorkeeper_access_token"] = doorkeeper_access_token
      env["doorkeeper_authorized_no_user"] = authorized_access_token_no_user?
      env["resource_owner"] = resource_owner
    end
  end
end
