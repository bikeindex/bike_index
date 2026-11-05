# frozen_string_literal: true

# Which page a viewer gets for a bike: the redesigned registration page, or the legacy
# bike show they've opted back to. Signed out, the opt-out lives in the session.
class RegistrationView
  def initialize(user:, session_show_legacy:)
    @user = user
    @session_show_legacy = session_show_legacy
  end

  def show_legacy?
    @user&.feature_registration_show_legacy? || @session_show_legacy.present?
  end

  # Kill switch for the redesign rollout - enabling the flag sends every viewer to the
  # classic page
  def redesign_enabled?
    return @redesign_enabled if defined?(@redesign_enabled)

    @redesign_enabled = !Flipper.enabled?(:registration_redesign_disabled)
  end

  def redesign_shown?(show_legacy: show_legacy?)
    redesign_enabled? && !show_legacy
  end

  # The bike's page as this viewer sees it, so a redirect lands there rather than
  # hopping through bikes#show
  def path(bike, show_legacy: show_legacy?, **query)
    routes = Rails.application.routes.url_helpers
    redesign_shown?(show_legacy:) ? routes.registration_path(bike, query) : routes.bike_path(bike, query)
  end
end
