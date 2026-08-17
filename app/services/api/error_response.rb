module API
  # What an exception means to an API client: the status, the message, and whether it's worth
  # reporting. Pure - API::Base.respond_to_error owns the logging and the Honeybadger notify.
  module ErrorResponse
    extend Functionable

    OAUTH_ERRORS = [APIAuthorization::Errors::OAuthUnauthorizedError,
      APIAuthorization::Errors::OAuthForbiddenError].freeze

    # Ordered - the first match wins, so anything carrying its own #status (every Grape
    # exception) falls through to status_for's default
    STATUSES = {
      APIAuthorization::Errors::OAuthUnauthorizedError => 401,
      APIAuthorization::Errors::OAuthForbiddenError => 403,
      API::EndpointNotFound => 404,
      ActiveRecord::RecordNotFound => 404,
      Rack::BadRequest => 400 # malformed request body (e.g. empty multipart)
    }.freeze

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

    def oauth_error?(error)
      OAUTH_ERRORS.any? { |klass| error.is_a?(klass) }
    end

    # Exception messages can carry invalid UTF-8 (scanner probe URLs, malformed params), and
    # #message can raise outright. The class name keeps status_for's mapping readable.
    def scrubbed_message(error)
      error.message.to_s.dup.force_encoding(Encoding::UTF_8).scrub
    rescue
      error.class.to_s
    end

    conceal :oauth_error?, :scrubbed_message
  end
end
