# frozen_string_literal: true

# Routes are written with underscores, so a path that only routes once its dashes are underscores
# redirects there - unless that changed a value the route reads as a param, like an organization's slug
module DashedPathRedirect
  extend Functionable

  def matches?(request) = request.path.include?("-") && routed?(request.path)

  def location(request) = [request.path.tr("-", "_"), request.query_string.presence].compact.join("?")

  conceal

  # private below here

  # Recognizes through the router rather than recognize_path, which skips redirects
  def routed?(path)
    underscored = ActionDispatch::Request.new(Rack::MockRequest.env_for(path.tr("-", "_")))
    Rails.application.routes.router.recognize(underscored) do |route, params|
      return route.defaults[:controller] != "errors" &&
          params.except(*route.defaults.keys).values.all? { path.include?(it) }
    end
    false
  end
end
