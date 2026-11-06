# frozen_string_literal: true

module EmailJobs
  class PosRegistrationMatchJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(pos_registration_match_id)
      return unless Flipper.enabled?(:pos_registration_match_emails)

      match = PosRegistrationMatch.find_by_id(pos_registration_match_id)
      return unless match&.pending? && match.merge_candidate?

      user = Bike.unscoped.find_by(id: match.bike_id)&.user
      return if user.blank?

      # A settled notification isn't sent again, so each match emails once
      notification = Notification.pos_registration_match.where(notifiable: match)
        .first_or_create(user:, bike_id: match.pos_bike_id)
      Notifications::Deliver.track_email(notification) do
        CustomerMailer.pos_registration_match_email(match, user).deliver_now
      end
    end
  end
end
