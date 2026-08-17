module API
  # grape_logging logs a re-raised exception's own #status, falling back to 500 - so app
  # exceptions that carry no status (RecordNotFound, OAuthUnauthorizedError) were recorded
  # as 500s while the client got the mapped one. Responding here - inside the logger, unlike
  # Grape's own error middleware - is what keeps the two in agreement.
  class ErrorResponder
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue => e
      API::Base.respond_to_error(e).finish
    end
  end
end
