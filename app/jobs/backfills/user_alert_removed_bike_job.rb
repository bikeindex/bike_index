# frozen_string_literal: true

module Backfills
  # Alerts about bikes that were deleted or transferred away stayed active, since nothing
  # revisited them. Only resolves - running AfterUserChangeJob would also create alerts,
  # and some of those kinds send email
  class UserAlertRemovedBikeJob < ApplicationJob
    sidekiq_options queue: "low_priority", retry: false

    def perform
      user_alerts = UserAlert.active.where.not(bike_id: nil).or(UserAlert.active.unfinished_registration)
      User.where(id: user_alerts.select(:user_id)).find_each do |user|
        UserAlert.resolve_without_bike(user)
        UserAlert.resolve_finished_registrations(user)
        UserAlert.refresh_alert_slugs(user)
      end
    end
  end
end
