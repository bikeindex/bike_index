# frozen_string_literal: true

module EmailJobs
  # Tells the owner when another email the shop registered their bike to said to merge the registrations
  class PosRegistrationMergedJob < ApplicationJob
    sidekiq_options queue: "notify", retry: 3

    def perform(pos_registration_match_id)
      return if skip_job?

      match = PosRegistrationMatch.find_by_id(pos_registration_match_id)
      return unless match&.merged? && match.different_email?

      # The account whose registration was merged
      user = match.bike&.user
      return if user.blank? || user.no_non_theft_notification

      notification = Notification.pos_registration_merged.where(notifiable: match, user:)
        .first_or_create(bike_id: match.pos_bike_id)
      Notifications::Deliver.track_email(notification) do
        CustomerMailer.pos_registration_merged_email(match, user).deliver_now
      end
    end
  end
end
