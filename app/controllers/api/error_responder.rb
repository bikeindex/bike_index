module API
  # grape_logging logs a hardcoded 500 for every exception it re-raises, so a handled error
  # was recorded as a 500 in production.log while the client got the real status. Responding
  # here - inside the logger, unlike Grape's own error middleware - keeps the two in agreement.
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
