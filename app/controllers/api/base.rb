require "grape_logging"

# TODO: creating all these classes here is ugly
# Ideally the validators would be less duplicative. But - this fixes the problem

module GrapeLogging
  module Loggers
    class BinxLogger < GrapeLogging::Loggers::Base
      def parameters(request, _)
        {remote_ip: IpAddressParser.forwarded_address(request), format: "json"}
      end
    end
  end
end

# validation enabled with case_insensitive_color: true (commented to help finding)
class CaseInsensitiveColor < Grape::Validations::Validators::Base
  def validate_param!(attr_name, params)
    val = params[attr_name]
    return if val.present? && Color.friendly_find(val)

    raise Grape::Exceptions::Validation.new params: [@scope.full_name(attr_name)], message: "must be one of: #{Color::ALL_NAMES}"
  end
end

# validation enabled with case_insensitive_ctype: true (commented to help finding)
class CaseInsensitiveCtype < Grape::Validations::Validators::Base
  def validate_param!(attr_name, params)
    val = params[attr_name]
    return if val.present? && Ctype.friendly_find(val)

    raise Grape::Exceptions::Validation.new params: [@scope.full_name(attr_name)], message: "must be one of: #{Ctype.pluck(:name).map(&:downcase)}"
  end
end

# validation enabled with case_insensitive_country: true (commented to help finding)
class CaseInsensitiveCountry < Grape::Validations::Validators::Base
  def validate_param!(attr_name, params)
    val = params[attr_name]
    return if val.present? && Country.friendly_find(val)

    raise Grape::Exceptions::Validation.new params: [@scope.full_name(attr_name)], message: "must be one of: #{Country.pluck(:name).map(&:downcase)}"
  end
end

# validation enabled with case_insensitive_propulsion_type: true (commented to help finding)
class CaseInsensitivePropulsionType < Grape::Validations::Validators::Base
  def validate_param!(attr_name, params)
    val = params[attr_name]
    return if val.present? && PropulsionType.friendly_find(val)

    raise Grape::Exceptions::Validation.new params: [@scope.full_name(attr_name)], message: "must be one of: #{PropulsionType::SLUGS}"
  end
end

# validation enabled with case_insensitive_cycle_type: true (commented to help finding)
class CaseInsensitiveCycleType < Grape::Validations::Validators::Base
  def validate_param!(attr_name, params)
    val = params[attr_name]
    return if val.present? && CycleType.friendly_find(val)

    raise Grape::Exceptions::Validation.new params: [@scope.full_name(attr_name)], message: "must be one of: #{CycleType::NAMES.values.map(&:downcase)}"
  end
end

module API
  class Base < Grape::API
    use GrapeLogging::Middleware::RequestLogger, instrumentation_key: "grape_key",
      include: [GrapeLogging::Loggers::BinxLogger.new,
        GrapeLogging::Loggers::FilterParameters.new]
    use API::ErrorResponder
    use ::APIAuthorization::OAuth2

    rescue_from :all do |e|
      API::Base.respond_to_error(e)
    end

    mount API::V3::RootV3
    mount API::V2::RootV2

    class << self
      # Anything raised in here escapes as a bare 500 with no JSON body and no
      # Honeybadger notify - the shape that makes API 500s invisible. Every path out
      # returns a Rack::Response, and every 5xx reports.
      def respond_to_error(e)
        message = error_message(e)
        # Rails.logger, since Grape's own logger writes to $stdout and never reaches production.log
        Rails.logger.error "#{e.class}: #{message}" unless Rails.env.test? # Breaks tests...
        status_code = status_code_for(e, message)
        notify_error(e) if status_code > 450 # Only notify for 500s
        message = "OAuth error: #{message}" if /APIAuthorization::Errors/.match?(e.class.to_s)
        opts = {error: message}
        opts[:trace] = e.backtrace&.first(10) unless Rails.env.production?
        error_response(opts, status_code)
      rescue => handler_error
        # Nothing fallible on this path - e.backtrace is what raised for some of the
        # exceptions that land here.
        notify_error(handler_error, context: {handling: e.class.to_s})
        error_response({error: "Internal Server Error"}, 500)
      end

      private

      # Reporting must never cost the response - notify is the last fallible call before
      # the fallback returns, and it reads e.message to build the notice.
      def notify_error(error, **opts)
        Honeybadger.notify(error, **opts) if Rails.env.production?
      rescue
        nil
      end

      # Exception messages can carry invalid UTF-8 (scanner probe URLs, malformed
      # params), and #message can raise outright. Falling back to the class name keeps
      # status_code_for's mapping intact, so a RecordNotFound stays a 404.
      def error_message(e)
        e.message.to_s.dup.force_encoding(Encoding::UTF_8).scrub
      rescue => message_error
        notify_error(message_error, context: {handling: e.class.to_s})
        e.class.to_s
      end

      def error_response(opts, status_code)
        Rack::Response.new(opts.to_json, status_code, {
          "Content-Type" => "application/json",
          "Access-Control-Allow-Origin" => "*",
          "Access-Control-Request-Method" => "*"
        })
      end

      def status_code_for(error, message)
        eclass = error.class.to_s
        if /OAuthUnauthorizedError/.match?(eclass)
          401
        elsif /OAuthForbiddenError/.match?(eclass)
          403
        elsif eclass.match?(/RecordNotFound/) || message.match?(/unable to find/i)
          404
        elsif error.is_a?(Rack::BadRequest) # malformed request body (e.g. empty multipart)
          400
        else
          (error.respond_to?(:status) && error.status) || 500
        end
      end
    end
  end
end
