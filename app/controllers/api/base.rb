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

# Heavily Influenced by winebouncer - antek-drzewiecki/wine_bouncer
# To make an endpoint require a token, include an authorizations key in the endpoint.
# authorizations: {oauth2: {scope: :public}}
# If no scope key is included, it will use default scope
require "doorkeeper/grape/authorization_decorator"
module ApiAuthorization
  class OAuth2 < Grape::Middleware::Base
    # include Doorkeeper::Grape::Helpers

    def auth_declaration
      @endpoint_auth_declaration || {}
    end

    def endpoint_protected?
      auth_declaration.key?(:oauth2)
    end

    def scope
      auth_declaration&.dig(:oauth2, :scope)&.to_sym
      # Currently not doing default scopes - but may in future: Doorkeeper.configuration.default_scopes
    end

    def doorkeeper_access_token
      @doorkeeper_access_token ||= Doorkeeper::OAuth::Token.authenticate(
        @doorkeeper_request,
        *Doorkeeper.configuration.access_token_methods,
      )
    end

    # config.define_resource_owner do
    #   User.find(doorkeeper_access_token.resource_owner_id) if doorkeeper_access_token
    # end

    def before
      # api_context = env["api.endpoint"]
      @endpoint_auth_declaration = env["api.endpoint"]&.options&.dig(:route_options, :authorizations)
      return unless endpoint_protected?
      @request = ActionDispatch::Request.new(env)
      @doorkeeper_request = Doorkeeper::Grape::AuthorizationDecorator.new(@request)
      pp doorkeeper_access_token
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
      message = "OAuth error: #{e}" if /WineBouncer::Errors/.match?(eclass)
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
