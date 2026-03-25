class IpSpoofAttackFilter
  FORBIDDEN_RESPONSE = [403, {"content-type" => "text/plain"}, ["Forbidden"]].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue ActionDispatch::RemoteIp::IpSpoofAttackError
    FORBIDDEN_RESPONSE
  rescue ActionView::Template::Error => e
    raise unless e.cause.is_a?(ActionDispatch::RemoteIp::IpSpoofAttackError)
    FORBIDDEN_RESPONSE
  end
end
