Sidekiq.configure_server do |config|
  config.redis = { driver: 'hiredis' }
end