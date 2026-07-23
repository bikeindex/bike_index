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

# Must sit below DebugExceptions/ShowExceptions: those rescue the raised IpSpoofAttackError
# and render it as a 500 before it can reach this filter. Above them it never fires.
Rails.application.config.middleware.insert_after ActionDispatch::DebugExceptions, IpSpoofAttackFilter
