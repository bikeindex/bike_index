class SignInThrottle
  MAX_REQUESTS = 10
  PERIOD = 60 # seconds

  THROTTLED_PATHS = %w[/session /oauth/token].freeze

  def initialize(app, cache: nil)
    @app = app
    @cache = cache || Redis.new
  end

  def call(env)
    request = Rack::Request.new(env)

    if throttled_request?(request)
      key = "sign_in_throttle:#{request.ip}"
      count = @cache.get(key).to_i

      if count >= MAX_REQUESTS
        return [429, {"content-type" => "text/plain", "retry-after" => PERIOD.to_s}, ["Too Many Requests"]]
      end

      @cache.multi do |pipeline|
        pipeline.incr(key)
        pipeline.expire(key, PERIOD)
      end
    end

    @app.call(env)
  end

  private

  def throttled_request?(request)
    request.post? && THROTTLED_PATHS.include?(request.path_info)
  end
end
