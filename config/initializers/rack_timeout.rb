if Rails.env.production?
  Rails.application.config.middleware.insert_after(
    ActionDispatch::RequestId, Rack::Timeout, service_timeout: 30, wait_timeout: 10
  )
end
