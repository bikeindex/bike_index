# frozen_string_literal: true

# Most paths are routed with underscores and marketing pages with dashes, so a path routed under its other
# spelling redirects there - unless the swap changed a value the route reads as a param, like an org's slug
module PathSpellingRedirect
  extend Functionable

  PROBE = "path_spelling_redirect.probe"

  def matches?(request) = !request.get_header(PROBE) && respelled(request.path).present?

  def location(request) = [respelled(request.path), request.query_string.presence].compact.join("?")

  conceal

  # private below here

  def respelled(path) = [path.tr("-", "_"), path.tr("_", "-")].find { it != path && routed?(it, path) }

  # Through the router rather than recognize_path, which skips redirects. PROBE keeps this route from
  # recognizing itself
  def routed?(respelled, path)
    request = ActionDispatch::Request.new(Rack::MockRequest.env_for(respelled, PROBE => true))
    Rails.application.routes.router.recognize(request) do |route, params|
      next unless route.app.matches?(request)

      return route.defaults[:controller] != "errors" && params.except(*route.defaults.keys).values.all? { path.include?(it) }
    end
    false
  end
end
