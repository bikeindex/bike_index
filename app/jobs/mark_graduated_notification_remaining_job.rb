# This job was added in PR#2347 because I wasn't sure why some graduated notifications failed to restore the organization.
# I figure that potentially it's timeouts - so I added this async processing version - but try to run in synchronously first
class MarkGraduatedNotificationRemainingJob < ApplicationJob
  sidekiq_options queue: "high_priority", retry: 2

  def perform(graduated_notification_id, marked_remaining_by_id = nil)
    graduated_notification = GraduatedNotification.find(graduated_notification_id)
    if graduated_notification.marked_remaining?
      return unless graduated_notification.user_registration_organization&.deleted_at.present?
    end

    graduated_notification.bike_organization.update(deleted_at: nil)
    if graduated_notification.primary_notification?
      graduated_notification.associated_notifications.each do |n|
        n.mark_remaining!(marked_remaining_by_id: marked_remaining_by_id, skip_async: true)
      end
    end
    # Update notification after bike organization restored and other notifications updated (in case of an error)
    graduated_notification.marked_remaining_at ||= Time.current
    graduated_notification.marked_remaining_by_id = marked_remaining_by_id
    graduated_notification.update!(status: :marked_remaining, updated_at: Time.current)
    # Long shot - but update any graduated notifications that might have been missed, just in case
    matching_notifications(graduated_notification).each do |match_notification|
      if graduated_notification.bike_organization.created_at.present? && match_notification.bike_organization.created_at.present?
        # remove the newer bike_organization, keep the older one
        if graduated_notification.bike_organization.created_at > match_notification.bike_organization.created_at
          graduated_notification.bike_organization.destroy
        end
      end
      match_notification.mark_remaining!(marked_remaining_by_id: marked_remaining_by_id, skip_async: true)
    end
    # Update user_registration_organization only once, after everything has already been updated
    if graduated_notification.primary_notification? && graduated_notification.user_registration_organization&.deleted?
      graduated_notification.user_registration_organization.update(deleted_at: nil)
    end
  end

  def matching_notifications(graduated_notification)
    graduated_notification.matching_notifications_including_self
      .where.not(id: graduated_notification.id).bike_graduated
  end
end
