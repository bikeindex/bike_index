require "grape_logging"

module GrapeLogging
  module Loggers
    class BinxLogger < GrapeLogging::Loggers::Base
      def parameters(request, _)
        {remote_ip: ForwardedIpAddress.parse(request), format: "json"}
      end
    end
  end
end

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

  # Heavily influenced by WineBouncer - antek-drzewiecki/wine_bouncer
  # To make an endpoint require a token, include an authorizations hash in the endpoint.
  # authorizations: {oauth2: {scope: :public}}
  # If no scope key is included, it will use default scope
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

module API
  class Base < Grape::API
    use GrapeLogging::Middleware::RequestLogger, instrumentation_key: "grape_key",
      include: [GrapeLogging::Loggers::BinxLogger.new,
        GrapeLogging::Loggers::FilterParameters.new]
    use ::ApiAuthorization::OAuth2
    mount API::V3::RootV3
    mount API::V2::RootV2

    def self.respond_to_error(e)
      logger.error e unless Rails.env.test? # Breaks tests...
      eclass = e.class.to_s
      message = "OAuth error: #{e}" if /ApiAuthorization::Errors/.match?(eclass)
      opts = {error: message || e.message}
      status_code = status_code_for(e, eclass)
      if Rails.env.production?
        Honeybadger.notify(e) if status_code > 450 # Only notify in production for 500s
      else
        opts[:trace] = e.backtrace[0, 10]
      end
      Rack::Response.new(opts.to_json, status_code, {
        "Content-Type" => "application/json",
        "Access-Control-Allow-Origin" => "*",
        "Access-Control-Request-Method" => "*"
      })
    end

    def self.status_code_for(error, eclass)
      if /OAuthUnauthorizedError/.match?(eclass)
        401
      elsif /OAuthForbiddenError/.match?(eclass)
        403
      elsif (eclass =~ /RecordNotFound/) || (error.message =~ /unable to find/i)
        404
      else
        (error.respond_to? :status) && error.status || 500
      end
    end
  end
end
