# frozen_string_literal: true

# The navbar renders from one fragment cached across every page, so its links can't resolve
# their own active state. Each ships the routes that make it active instead, the layout
# stamps the body with the route it rendered, and page-block--navbar compares the two.
# The uncached org sidebar ships nothing and compares here, through #matches?.
module NavRoute
  extend Functionable

  def current(controller_namespace:, controller_name:, action_name:)
    "#{[controller_namespace, controller_name].compact.join("/")}##{action_name}"
  end

  # The attributes page-block--navbar reads off a link. Neither means it can never activate
  def data(active, path)
    return {active_path: true} if active == :auto

    (active == :match_controller) ? routes_data(controller_for(path)) : {}
  end

  def routes_data(routes)
    routes.present? ? {active_routes: routes} : {}
  end

  # Space separated "controller#action", where an action-less entry takes any action
  def matches?(routes, current_route)
    return false if routes.blank?

    controller, action = current_route.split("#")
    routes.split(" ").any? do |route|
      route_controller, route_action = route.split("#")
      route_controller == controller && (route_action.nil? || route_action == action)
    end
  end

  # nil for anything this app doesn't route — recognize_path reads an absolute URL's host
  # as part of the path, so the ambassador menu's discuss link would come back as the root
  def controller_for(path)
    return nil unless path.to_s.start_with?("/")

    Rails.application.routes.recognize_path(path)[:controller]
  rescue ActionController::RoutingError
    nil
  end
end
