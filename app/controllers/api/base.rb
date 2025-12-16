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
    use ::APIAuthorization::OAuth2
    mount API::V3::RootV3
    mount API::V2::RootV2

    def self.respond_to_error(e)
      logger.error e unless Rails.env.test? # Breaks tests...
      eclass = e.class.to_s
      message = "OAuth error: #{e}" if /APIAuthorization::Errors/.match?(eclass)
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
