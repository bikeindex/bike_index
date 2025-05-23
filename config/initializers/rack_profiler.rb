if Rails.env != "test"
  require "rack-mini-profiler"
  require "flamegraph"

  # initialization is skipped so trigger it
  Rack::MiniProfilerRails.initialize!(Rails.application)

  # Store in redis because production usage. Fails without configuring storage options :(
  Rack::MiniProfiler.config.storage_options = {}
  Rack::MiniProfiler.config.storage = Rack::MiniProfiler::RedisStore
  Rack::MiniProfiler.config.position = "right"

  Rack::MiniProfilerRails.subscribe("render.view_component") do |_name, start, finish, _id, payload|
    Rack::MiniProfilerRails.render_notification_handler(
      Rack::MiniProfilerRails.shorten_identifier(payload[:identifier]),
      finish,
      start
    )
  end
end
