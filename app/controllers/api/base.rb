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

module API
  class Base < Grape::API
    use GrapeLogging::Middleware::RequestLogger, instrumentation_key: "grape_key",
                                                 include: [GrapeLogging::Loggers::BinxLogger.new,
                                                   GrapeLogging::Loggers::FilterParameters.new]
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
      }).finish
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
