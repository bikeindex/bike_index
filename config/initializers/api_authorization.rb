# Heavily influenced by WineBouncer - antek-drzewiecki/wine_bouncer
# To make an endpoint require a token, include an authorizations hash in the endpoint.
# authorizations: {oauth2: {scope: :public}}
# If no scope key is included, it will use default scope
module ApiAuthorization
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
        *Doorkeeper.configuration.access_token_methods,
      )
    end

    def resource_owner
      @resource_owner = User.find_by_id(doorkeeper_access_token&.resource_owner_id)
    end

    def doorkeeper_authorize!
      return if doorkeeper_access_token&.acceptable?(endpoint_scopes) &&
        resource_owner.present?

      if doorkeeper_access_token.blank? || !doorkeeper_access_token.accessible?
        error = Doorkeeper::OAuth::InvalidTokenResponse.from_access_token(doorkeeper_access_token)
        raise ApiAuthorization::Errors::OAuthUnauthorizedError, error
      else
        error = Doorkeeper::OAuth::ForbiddenTokenResponse.from_scopes(endpoint_scopes)
        raise ApiAuthorization::Errors::OAuthForbiddenError, error
      end
    end

    # Before grape actions happen
    def before
      @endpoint_auth_declaration = env["api.endpoint"]&.options&.dig(:route_options, :authorizations)
      return unless endpoint_protected?
      doorkeeper_authorize!
      env["doorkeeper_access_token"] = doorkeeper_access_token
      env["resource_owner"] = resource_owner
    end
  end
end
