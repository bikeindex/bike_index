class GraduatedNotification < ApplicationRecord
  STATUS_ENUM = { pending: 0, delivered: 1, marked_remaining: 2 }.freeze
  belongs_to :bike
  belongs_to :bike_organization
  belongs_to :user
  belongs_to :organization
  belongs_to :primary_bike, class_name: "Bike"
  belongs_to :primary_notification, class_name: "GraduatedNotification"

  has_many :secondary_notifications, class_name: "GraduatedNotification", foreign_key: :primary_notification_id

  before_validation :set_calculated_attributes
  after_commit :update_associated_notifications, if: :persisted?

  enum status: STATUS_ENUM

  attr_accessor :skip_update

  scope :active, -> { where(status: active_statuses) }
  scope :primary_notification, -> { where(primary_notification_id: nil) }
  scope :secondary_notifications, -> { where.not(primary_notification_id: nil) }
  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.active_statuses; ["delivered"] end

  def self.associated_notifications_including_self(id, primary_notification_id)
    return none unless primary_notification_id.present?
    where(primary_notification_id: primary_notification_id)
  end

  def self.associated_notifications(id, primary_notification_id)
    associated_notifications_including_self(id, primary_notification_id).where.not(id: id)
  end

  def self.bikes
    Bike.unscoped.includes(:graduated_notifications)
        .where(graduated_notifications: { id: pluck(:id) })
  end

  def self.bikes_to_notify_without_notifications(organization)
    Bike.unscoped.includes(:graduated_notifications, :ownerships)
        .where(graduated_notifications: { id: nil })
        .where("ownerships.created_at < ?", Time.current - organization.graduated_notification_interval)
        .reorder("ownerships.created_at")
  end

  def self.bikes_to_notify_expired_notifications(organization)
    Bike.unscoped.includes(:graduated_notifications, :ownerships)
        .where.not(graduated_notifications: { marked_remaining_at: nil })
        .where("graduated_notifications.marked_remaining_at < ?", Time.current - organization.graduated_notification_interval)
        .where(graduated_notifications: { id: pluck(:id) })
        .reorder(:created_at)
  end

  def self.bike_ids_to_notify(organization)
    return Bike.nil unless organization.graduated_notification_interval.present?
    bikes_to_notify_without_notifications(organization).pluck(:id) +
      bikes_to_notify_expired_notifications(organization).pluck(:id)
  end

  # Get it unscoped, because we really want it
  def bike; @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil end

  def primary_bike?; bike_id == primary_bike_id end

  def email_success?; delivery_status == "email_success" end

  # Get it unscoped, because we delete it
  def bike_organization; bike_organization_id.present? ? BikeOrganization.unscoped.find_by_id(bike_organization_id) : nil end

  def active?; self.class.active_statuses.include?(status) end

  def primary_notification?; id.present? && id == primary_notification_id end

  def secondary_notification?; !primary_notification? end

  def associated_notifications; self.class.associated_notifications(id, primary_notification_id) end

  def associated_notifications_including_self; self.class.associated_notifications_including_self(id, primary_notification_id) end

  def associated_bikes
    return Bike.none unless user.present? || bike.present?
    # If the notifications have been processed, the bikes are removed from the organization - using associated_notifications will get them
    bike_ids = user_or_email_bike_ids + associated_notifications.pluck(:bike_id) + [bike_id]
    # We want to order the bikes by when the ownership was created, so perform that on either result
    Bike.unscoped.where(id: bike_ids).includes(:ownerships).reorder("ownerships.created_at DESC")
  end

  def send_email?
    organization.deliver_graduated_notifications? && primary_notification?
  end

  def mark_remaining!(resolved_at: nil)
    self.marked_remaining_at ||= resolved_at || Time.current
    # We don't want to re-mark remaining
    return true unless marked_remaining_at_changed?
    update(updated_at: Time.current)
    bike_organization.update(deleted_at: nil)
    associated_notifications.each { |n| n.update(updated_at: Time.current, skip_update: true) }
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
    self.marked_remaining_link_token ||= SecurityTokenizer.new_token if pending?
    self.status = calculated_status
  end

  def update_associated_notifications
    return true if skip_update
    return true unless primary_notification? && persisted?

    organization.graduated_notifications.where(primary_notification_id: nil, primary_bike_id: bike_id)
                .where.not(id: id)
                .each { |n| n.update(updated_at: Time.current, skip_update: true) }
  end

  # This is here because we're calling it from the creation job, and I like it here more than in the job
  def process_notification!
    return true if email_success?
    bike_organization&.destroy

    OrganizedMailer.graduated_notification(self).deliver_now if send_email?
    # I'm not sure how to make this more representative, similar issue in parking_notification
    update(delivery_status: "email_success")
  end

  # Right now, just static - but we're going to make it configurable
  def email_title
    "Renew your bike permit"
  end

  private

  def calculated_status
    # Because prior to commit, the value for the current notification isn't set
    return "marked_remaining" if marked_remaining_at.present? || associated_notifications_including_self.marked_remaining.any?
    # Similar - if this is the primary_notification, we want to make sure it's marked delivered during save
    delivery_status == "email_success" || primary_notification.present? && primary_notification.email_success? ? "delivered" : "pending"
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
    if user_id.present?
      existing_notification = GraduatedNotification.where(user_id: user_id, created_at: potential_matching_period)
                                                        .email_success.first
    end
    existing_notification ||= associated_notifications_including_self.email_success.first
    existing_notification
  end

  def user_or_email_bike_ids
    if user_id.present?
      bikes = Bike.unscoped.current.includes(:ownerships).where(ownerships: { current: true, user_id: user_id })
                  .organization(organization_id)
    else
      bikes = organization.bikes.includes(:ownerships).where(owner_email: bike.owner_email)
    end
    bikes.where("ownerships.created_at < ?", created_at || Time.current).pluck("bikes.id")
  end
end
