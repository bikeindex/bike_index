# frozen_string_literal: true

module EmailJobs
  class PosRegistrationMatchJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(pos_registration_match_id)
      return if skip_job?

      with_redlock(pos_registration_match_id) do
        match = PosRegistrationMatch.find_by_id(pos_registration_match_id)
        # Rechecked, since a theft or a transfer can come after the match
        next unless match&.confirmable?

        match.add_review_reasons!(PosRegistrationMatch.review_reasons_for(match.bike, match.pos_bike))
        next unless match.merge_candidate?

        notification = Notification.pos_registration_match.where(notifiable: match)
          .first_or_create(user: match.bike.user, bike_id: match.pos_bike_id)
        # Skips a notification that's already been sent
        Notifications::Deliver.track_email(notification) do
          CustomerMailer.pos_registration_match_email(match, notification.user).deliver_now
        end
      end
    end
  end
end
