module GrapeErrors
  extend Functionable

  # A type, so the 404 doesn't depend on the message - matching /unable to find/ turned
  # real bugs worded that way into unreported 404s
  class EndpointNotFound < StandardError
  end

  OAUTH_ERRORS = [APIAuthorization::Errors::OAuthUnauthorizedError,
    APIAuthorization::Errors::OAuthForbiddenError].freeze

  # Ordered by ancestry match - first entry wins. Grape's own exceptions carry #status, so
  # they're deliberately absent; status_for falls back to that.
  STATUSES = {
    APIAuthorization::Errors::OAuthUnauthorizedError => 401,
    APIAuthorization::Errors::OAuthForbiddenError => 403,
    EndpointNotFound => 404,
    ActiveRecord::RecordNotFound => 404,
    Rack::BadRequest => 400 # malformed request body (e.g. empty multipart)
  }.freeze

  # grape_logging logs an exception's own #status, defaulting to 500 when there isn't one -
  # answering here, before it re-raises, keeps the logged status and the response agreed.
  class Responder
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue => e
      GrapeErrors.response_for(e).finish
    end
  end

  # A Rack::Response, unfinished - Responder .finishes it, Grape's rescue_from returns it bare
  def response_for(error)
    message = message_for(error)
    # Rails.logger, since Grape's own logger writes to $stdout and never reaches production.log
    Rails.logger.error "#{error.class}: #{message}" unless Rails.env.test? # Breaks tests...
    status = status_for(error)
    notify(error) if report?(status)
    opts = {error: message}
    opts[:trace] = error.backtrace&.first(10) unless Rails.env.production?
    rack_response(opts, status)
  rescue => handler_error
    # Nothing fallible on this path - error.backtrace is what raised for some of the
    # exceptions that land here.
    notify(handler_error, context: {handling: error.class.to_s})
    rack_response({error: "Internal Server Error"}, 500)
  end

  def status_for(error)
    matched = STATUSES.find { |klass, _| error.is_a?(klass) }
    return matched.last if matched

    (error.respond_to?(:status) && error.status) || 500
  end

  def message_for(error)
    oauth_error?(error) ? "OAuth error: #{scrubbed_message(error)}" : scrubbed_message(error)
  end

  # A 4xx is the API answering correctly - only the unexpected is worth reporting
  def report?(status) = status >= 500

  #
  # private below here
  #

  def oauth_error?(error) = OAUTH_ERRORS.any? { |klass| error.is_a?(klass) }

  # Exception messages can carry invalid UTF-8 (scanner probes, malformed params) or raise outright
  def scrubbed_message(error)
    error.message.to_s.dup.force_encoding(Encoding::UTF_8).scrub
  rescue
    error.class.to_s
  end

  # Reporting must never cost the response - notify reads error.message to build the notice
  def notify(error, **opts)
    Honeybadger.notify(error, **opts) if Rails.env.production?
  rescue
    nil
  end

  def rack_response(opts, status)
    Rack::Response.new(opts.to_json, status, {
      "Content-Type" => "application/json",
      "Access-Control-Allow-Origin" => "*",
      "Access-Control-Request-Method" => "*"
    })
  end

  conceal :oauth_error?, :scrubbed_message, :notify, :rack_response
end
