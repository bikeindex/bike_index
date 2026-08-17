# This job was added in PR#2347 because I wasn't sure why some graduated notifications failed to restore the organization.
# I figure that potentially it's timeouts - so I added this async processing version - but try to run in synchronously first
class MarkGraduatedNotificationRemainingJob < ApplicationJob
  sidekiq_options queue: "high_priority", retry: 2

  def perform(graduated_notification_id, marked_remaining_by_id = nil)
    mark_remaining(graduated_notification_id, marked_remaining_by_id, [])
  end

  def matching_notifications(graduated_notification)
    graduated_notification.matching_notifications_including_self
      .where.not(id: graduated_notification.id).bike_graduated
  end

  private

  # A notification and its matches each mark the others, and none reaches marked_remaining
  # until after the loops below - so marking_ids, threaded through every branch, is the only
  # thing ending the recursion. Returns it so siblings don't re-traverse each other.
  def mark_remaining(graduated_notification_id, marked_remaining_by_id, marking_ids)
    return marking_ids if marking_ids.include?(graduated_notification_id)

    graduated_notification = GraduatedNotification.find(graduated_notification_id)
    if graduated_notification.marked_remaining?
      return marking_ids unless graduated_notification.user_registration_organization&.deleted_at.present?
    end
    marking_ids += [graduated_notification_id]

    graduated_notification.bike_organization.update(deleted_at: nil)
    if graduated_notification.primary_notification?
      marking_ids = graduated_notification.associated_notifications.reduce(marking_ids) do |ids, n|
        mark_remaining(n.id, marked_remaining_by_id, ids)
      end
    end
    # Update notification after bike organization restored and other notifications updated (in case of an error)
    graduated_notification.marked_remaining_at ||= Time.current
    graduated_notification.marked_remaining_by_id = marked_remaining_by_id
    graduated_notification.update!(status: :marked_remaining, updated_at: Time.current)
    # Long shot - but update any graduated notifications that might have been missed, just in case
    marking_ids = matching_notifications(graduated_notification).reduce(marking_ids) do |ids, match_notification|
      if graduated_notification.bike_organization.created_at.present? && match_notification.bike_organization.created_at.present?
        # remove the newer bike_organization, keep the older one
        if graduated_notification.bike_organization.created_at > match_notification.bike_organization.created_at
          graduated_notification.bike_organization.destroy
        end
      end
      mark_remaining(match_notification.id, marked_remaining_by_id, ids)
    end
    # Update user_registration_organization only once, after everything has already been updated
    if graduated_notification.primary_notification? && graduated_notification.user_registration_organization&.deleted?
      graduated_notification.user_registration_organization.update(deleted_at: nil)
    end
    marking_ids
  end
end
