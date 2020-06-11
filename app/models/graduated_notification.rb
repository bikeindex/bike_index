class GraduatedNotification < ApplicationRecord
  STATUS_ENUM = { pending: 0, active: 1, marked_remaining: 2 }.freeze
  PENDING_PERIOD = 24.hours
  belongs_to :bike
  belongs_to :bike_organization
  belongs_to :user
  belongs_to :organization
  belongs_to :primary_bike, class_name: "Bike"
  belongs_to :primary_notification, class_name: "GraduatedNotification"

  has_many :secondary_notifications, class_name: "GraduatedNotification", foreign_key: :primary_notification_id

  validates_presence_of :bike_id, :organization_id, :bike_organization_id

  before_validation :set_calculated_attributes
  after_commit :update_associated_notifications, if: :persisted?

  enum status: STATUS_ENUM

  attr_accessor :skip_update

  scope :current, -> { where(status: current_statuses) }
  scope :processed, -> { where(status: processed_statuses) }
  scope :unprocessed, -> { where(status: unprocessed_statuses) }
  scope :not_marked_remaining, -> { where.not(status: "marked_remaining") }
  scope :primary_notifications, -> { where("primary_notification_id = id") }
  scope :secondary_notifications, -> { where.not("primary_notification_id  = id") }
  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.current_statuses; statuses - ["marked_remaining"] end

  def self.processed_statuses; %w[active marked_remaining] end

  def self.unprocessed_statuses; statuses - processed_statuses end

  def self.associated_notifications_including_self(graduated_notification)
    where(organization_id: graduated_notification.organization_id,
          primary_bike_id: graduated_notification.primary_bike_id,
          primary_notification_id: nil)
      .or(where(primary_notification_id: graduated_notification.primary_notification_id))
  end

  def self.associated_notifications(graduated_notification)
    associated_notifications_including_self(graduated_notification)
      .where.not(id: graduated_notification.id)
  end

  def self.bikes
    Bike.unscoped.includes(:graduated_notifications)
        .where(graduated_notifications: { id: pluck(:id) })
  end

  def self.bikes_to_notify_without_notifications(organization)
    organization.bikes.includes(:graduated_notifications, :ownerships)
      .where(graduated_notifications: { id: nil })
      .where("ownerships.created_at < ?", Time.current - organization.graduated_notification_interval)
      .reorder("ownerships.created_at ASC") # Use ascending so older are processed first
  end

  def self.bikes_to_notify_expired_notifications(organization)
    organization.bikes.includes(:graduated_notifications, :ownerships)
      .where.not(graduated_notifications: { marked_remaining_at: nil })
      .where("graduated_notifications.marked_remaining_at < ?", Time.current - organization.graduated_notification_interval)
      .where(graduated_notifications: { id: pluck(:id) })
      .reorder("ownerships.created_at ASC") # Use ascending so older are processed first
  end

  def self.bike_ids_to_notify(organization)
    return Bike.nil unless organization&.graduated_notification_interval&.present?
    bikes_to_notify_without_notifications(organization).pluck(:id) +
      bikes_to_notify_expired_notifications(organization).pluck(:id)
  end

  # Get it unscoped, because we really want it
  def bike; @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil end

  def primary_bike?; bike_id == primary_bike_id end

  def email_success?; delivery_status == "email_success" end

  # Get it unscoped, because we delete it
  def bike_organization; bike_organization_id.present? ? BikeOrganization.unscoped.find_by_id(bike_organization_id) : nil end

  def current?; self.class.current_statuses.include?(status) end

  def processed?; self.class.processed_statuses.include?(status) end

  def unprocessed?; !processed? end

  # Necessary to match parking_notification method
  def resolved?; marked_remaining? end

  def primary_notification?; id.present? && id == primary_notification_id end

  def secondary_notification?; !primary_notification? end

  def associated_notifications; self.class.associated_notifications(self) end

  def associated_notifications_including_self; self.class.associated_notifications_including_self(self) end

  def mail_snippet; MailSnippet.where(kind: "graduated_notification", organization_id: organization_id).first end

  def associated_bikes
    return Bike.none unless user.present? || bike.present?
    # We want to order the bikes by when the ownership was created, so perform that on either result
    (processed? ? bikes_from_associated_notifications : user_or_email_bikes).reorder("ownerships.created_at DESC")
  end

  def send_email?
    organization.deliver_graduated_notifications? && primary_notification?
  end

  def pending_period_ends_at
    # provide a consistent answer for all associated notifications
    return primary_notification.pending_period_ends_at if primary_notification.present? && !primary_notification?
    (created_at || Time.current) + PENDING_PERIOD
  end

  # At least for now, don't email immediately - but maybe drop this in the future
  def in_pending_period?; pending_period_ends_at > Time.current end

  def mark_remaining!(resolved_at: nil)
    return true unless marked_remaining_at.blank?
    self.marked_remaining_at ||= resolved_at || Time.current
    # We don't want to re-mark remaining
    update(updated_at: Time.current)
    bike_organization.update(deleted_at: nil)
    associated_notifications.each { |n| n.update(updated_at: Time.current, skip_update: true, marked_remaining_at: marked_remaining_at) }
    # Long shot - but update any graduated notifications that might have been missed, just in case
    organization.graduated_notifications.where(bike_id: bike_id).active.each do |pre_notification|
      if bike_organization.created_at.present? && pre_notification.bike_organization.created_at.present?
        # remove the newer bike_organization, keep the older one
        bike_organization.destroy if bike_organization.created_at > pre_notification.bike_organization.created_at
      end
      pre_notification.mark_remaining!
    end
    true
  end

  def set_calculated_attributes
    self.bike_organization_id ||= calculated_bike_organization&.id
    self.user ||= bike.user
    self.email ||= calculated_email
    self.primary_bike_id ||= associated_bikes.last&.id
    self.primary_notification ||= calculated_primary_notification
    self.marked_remaining_link_token ||= SecurityTokenizer.new_token
    self.status = calculated_status
  end

  def update_associated_notifications
    return true if skip_update || !primary_notification?
    self.class.associated_notifications(self)
      .each { |n| n.update(updated_at: Time.current, skip_update: true) }
  end

  def processable?
    return true if processed?
    return false unless organization.deliver_graduated_notifications?
    # The primary notification should be the first one to process, so skip processing if it isn't
    return false unless primary_notification? || (primary_notification.present? && primary_notification.processed?)
    if primary_notification? && associated_bike_ids_missing_notifications.any?
      # We haven't created all the relevant graduated notifications, create them before processing
      associated_bike_ids_missing_notifications.each do |b_id|
        CreateGraduatedNotificationWorker.perform_async(organization_id, b_id)
      end
      return false
    end
    # Also, skip running immediately - at least for now
    !in_pending_period?
  end

  # This is here because we're calling it from the creation job, and I like it here more than in the job
  def process_notification
    return true if email_success?
    return false unless processable?

    bike_organization&.destroy!

    # deliver email before everything, so if fails, we send when we try again
    OrganizedMailer.graduated_notification(self).deliver_now if send_email?
    update(processed_at: Time.current, delivery_status: "email_success", skip_update: true)

    return true unless primary_notification?
    # Update the associated notifications after updating the primary notification, so if we fail, they can be updated by the worker
    associated_notifications.each { |notification| notification.process_notification }
    true
  end

  def subject
    return mail_snippet.subject if (mail_snippet&.subject).present?
    "Renew your #{bike&.type || "Bike"} registration with #{organization&.short_name}"
  end

  private

  def calculated_status
    # Because prior to commit, the value for the current notification isn't set
    return "marked_remaining" if marked_remaining_at.present? || associated_notifications_including_self.marked_remaining.any?
    # Similar - if this is the primary_notification, we want to make sure it's marked processed during save
    (email_success? || primary_notification.present? && primary_notification.email_success?) ? "active" : "pending"
  end

  def calculated_email
    user&.email || bike.owner_email
  end

  def calculated_bike_organization
    BikeOrganization.where(bike_id: bike_id, organization_id: organization_id)
                    .where("created_at < ?", created_at || Time.current)
                    .reorder(:id).last
  end

  # THIS CAN BE NIL! - the primary_notification might not exist yet
  def calculated_primary_notification
    return primary_notification if primary_notification_id.present? # Use already calculated value
    # If an associated notification was already emailed out, use that notification
    return existing_sent_notification if existing_sent_notification.present?
    return self if primary_bike? && primary_notification_id.blank? # This is the primary notification
    notifications = organization.graduated_notifications.where(bike_id: primary_bike_id)
    # If there aren't any notifications, return nil
    # Also - if the organization doesn't have an interval set, we can't do anything, so skip it
    return notifications&.first if organization.graduated_notification_interval.blank?
    # Otherwise, only match on notifications from the same period
    notifications.where(created_at: potential_matching_period)
                 .or(notifications.where(marked_remaining_at: potential_matching_period)).first
  end

  def potential_matching_period
    c_at = created_at || Time.current
    (c_at - organization.graduated_notification_interval)..(c_at + organization.graduated_notification_interval)
  end

  def existing_sent_notification
    if user_id.present? && organization.graduated_notification_interval.present?
      existing_notification = GraduatedNotification.where(user_id: user_id, created_at: potential_matching_period)
        .email_success.first
    end
    existing_notification ||= associated_notifications_including_self.email_success.first
    existing_notification
  end

  def user_or_email_bikes
    if user_id.present?
      Bike.unscoped.current.includes(:ownerships).where(ownerships: { current: true, user_id: user_id })
        .organization(organization_id)
    else
      organization.bikes.includes(:ownerships).where(owner_email: bike.owner_email)
    end
  end

  def bikes_from_associated_notifications
    # If the notifications have been processed, the bikes are removed from the organization - using associated_notifications will get them
    Bike.unscoped.where(id: associated_notifications.pluck(:bike_id) + [bike_id]).includes(:ownerships)
  end

  def associated_bike_ids_missing_notifications
    associated_bike_ids = associated_bikes.pluck(:id)
    associated_notification_bike_ids = associated_notifications_including_self.pluck(:bike_id)
    associated_bike_ids - associated_notification_bike_ids
  end
end
