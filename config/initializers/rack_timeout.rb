if Rails.env.production? || Rails.env.staging?
  Rails.application.config.middleware.insert_after(
    ActionDispatch::RequestId, Rack::Timeout, service_timeout: 30, wait_timeout: 10
  )
  # The gem's base.rb auto-inits a state-change observer that writes two plain
  # "source=rack-timeout ..." INFO lines per request to Rails.logger, which
  # would pollute the Lograge JSON stream. Honeybadger captures the actual
  # timeout exceptions independently, so the observer is pure noise here.
  Rack::Timeout::Logger.disable
end
