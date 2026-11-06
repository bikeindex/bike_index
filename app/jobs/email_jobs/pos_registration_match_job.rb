# frozen_string_literal: true

module EmailJobs
  class PosRegistrationMatchJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(pos_registration_match_id)
      return unless Flipper.enabled?(:pos_registration_match_emails)

      match = PosRegistrationMatch.find_by_id(pos_registration_match_id)
      return if match.blank?

      # Rechecked, since a theft or a transfer can come after the match
      notification = match.with_lock do
        bike = Bike.unscoped.find_by(id: match.bike_id)
        pos_bike = Bike.unscoped.find_by(id: match.pos_bike_id)
        next unless match.confirmable?(bike, pos_bike)

        match.add_review_reasons!(PosRegistrationMatch.review_reasons_for(bike, pos_bike))
        next unless match.merge_candidate?

        Notification.pos_registration_match.where(notifiable: match).first_or_create(user: bike.user, bike_id: pos_bike.id)
      end
      return if notification.blank?

      # The notification's lock, not the match's, so confirming isn't held up by the send. Concurrent runs send once
      notification.with_lock do
        Notifications::Deliver.track_email(notification) do
          CustomerMailer.pos_registration_match_email(match, notification.user).deliver_now
        end
      end
    end
  end
end
