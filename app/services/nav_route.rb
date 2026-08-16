# frozen_string_literal: true

# The navbar renders from one fragment cached across every page, so its links can't resolve
# their own active state. Each ships the routes that make it active instead, the layout
# stamps the body with the route it rendered, and page-block--navbar compares the two.
module NavRoute
  extend Functionable

  def current(controller_namespace:, controller_name:, action_name:)
    "#{[controller_namespace, controller_name].compact.join("/")}##{action_name}"
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
