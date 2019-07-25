module I18n
  # Taken from https://github.com/ruby-i18n/i18n
  # Isolates i18n config by thread
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    ensure
      Thread.current[:i18n_config] = I18n::Config.new
    end
  end
end
