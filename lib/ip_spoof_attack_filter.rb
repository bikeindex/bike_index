class IpSpoofAttackFilter
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue ActionDispatch::RemoteIp::IpSpoofAttackError
    forbidden_response
  rescue ActionView::Template::Error => e
    raise unless e.cause.is_a?(ActionDispatch::RemoteIp::IpSpoofAttackError)
    forbidden_response
  end

  private

  def forbidden_response
    [403, {"content-type" => "text/plain"}, ["Forbidden"]]
  end
end
