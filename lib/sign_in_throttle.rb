class SignInThrottle
  PERIOD = 60 # seconds

  SIGN_IN_PATHS = %w[/session /oauth/token].freeze
  SIGN_IN_MAX = 10

  SENSITIVE_PATHS = %w[
    /session/create_magic_link
    /session/sign_in_with_magic_link
    /users/send_password_reset_email
    /users/update_password_with_reset_token
    /users/resend_confirmation_email
  ].freeze
  SENSITIVE_PATH_PREFIX = "/user_emails/".freeze
  SENSITIVE_SUFFIXES = %w[/resend_confirmation].freeze
  SENSITIVE_MAX = 5

  cattr_accessor :enabled, default: true

  def initialize(app, cache: nil)
    @app = app
    @cache = cache || Redis.new
  end

  def call(env)
    request = Rack::Request.new(env)
    return @app.call(env) unless enabled && request.post?

    limit = request_limit(request)
    if limit
      key = "sign_in_throttle:#{limit}:#{request.ip}"
      count = @cache.get(key).to_i

      if count >= limit
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

  def request_limit(request)
    path = request.path_info
    if SIGN_IN_PATHS.include?(path)
      SIGN_IN_MAX
    elsif SENSITIVE_PATHS.include?(path) || sensitive_member_path?(path)
      SENSITIVE_MAX
    end
  end

  def sensitive_member_path?(path)
    path.start_with?(SENSITIVE_PATH_PREFIX) &&
      SENSITIVE_SUFFIXES.any? { |suffix| path.end_with?(suffix) }
  end
end
