require 'grape_logging'

module GrapeLogging
  module Loggers
    class BinxLogger < GrapeLogging::Loggers::Base
      def parameters(request, _)
        { ip: request.env['CF-Connecting-IP'] }
      end
    end
  end
end

module API
  class Base < Grape::API
    use GrapeLogging::Middleware::RequestLogger, instrumentation_key: 'grape_key',
                                                 include: [GrapeLogging::Loggers::BinxLogger.new,
                                                           GrapeLogging::Loggers::FilterParameters.new]
    mount API::V2::Root

    def self.respond_to_error(e)
      logger.error e
      eclass = e.class.to_s
      message = "OAuth error: #{e.to_s}" if eclass.match('WineBouncer::Errors')
      status = case 
      when eclass.match('OAuthUnauthorizedError')
        401
      when eclass.match('OAuthForbiddenError')
        403
      when eclass.match('RecordNotFound'), e.message.match(/unable to find/i).present?
        404
      else
        (e.respond_to? :status) && e.status || 500
      end
      opts = { error: "#{message || e.message}" }
      opts[:trace] = e.backtrace[0,10] unless Rails.env.production?
      Rack::Response.new(opts.to_json, status, {
        'Content-Type' => 'application/json',
        'Access-Control-Allow-Origin' => '*',
        'Access-Control-Request-Method' => '*',
      }).finish
    end
  end
end