redis_host = 'localhost:6379'

Resque.redis = redis_host

require 'resque/failure/airbrake'

Resque.redis = ENV['REDISTOGO_URL'] || 'localhost:6379'

Resque::Failure::Airbrake.configure do |config|
  config.api_key = ENV['AIRBRAKE_API_KEY']
  config.secure = true
end

Resque::Failure.backend = Resque::Failure::Airbrake
