# frozen_string_literal: true

# Which page a viewer gets for a bike: the redesigned registration page, or the legacy
# bike show they've opted back to. Signed out, the opt-out lives in the session.
module RegistrationView
  extend Functionable

  def show_legacy?(user:, session:)
    user&.feature_registration_show_legacy? || session[:registration_show_legacy].present?
  end

  # The bike's page as this viewer sees it, so a redirect lands there rather than
  # hopping through bikes#show
  def path(bike, user:, session:, show_legacy: show_legacy?(user:, session:), **query)
    routes = Rails.application.routes.url_helpers
    show_legacy ? routes.bike_path(bike, query) : routes.registration_path(bike, query)
  end
end
