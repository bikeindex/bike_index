# t.references :primary_graduated_notification, index: true

# t.text :marked_remaining_link_token
# t.datetime :marked_remaining_at

# t.integer :status, default: 0

# t.references :organization, index: true
# t.references :bike, index: true
# t.references :user, index: true
# t.references :primary_notification, index: true
# t.string :email

# t.string :delivery_status

class GraduatedNotification < ApplicationRecord
  STATUS_ENUM = { pending: 0, delivered: 1, marked_remaining: 2 }.freeze
  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :primary_notification, class_name: "GraduatedNotification"

  has_many :secondary_notifications, class_name: "GraduatedNotification", foreign_key: :primary_notification_id

  before_validation :set_calculated_attributes
  after_create :process_notification

  enum status: STATUS_ENUM

  scope :active, -> { where(status: active_statuses) }
  scope :primary_notification, -> { where(primary_notification_id: nil) }
  scope :secondary_notifications, -> { where.not(primary_notification_id: nil) }
  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.active_statuses; ["delivered"] end

  def self.associated_notifications_including_self(id, primary_notification_id)
    potential_id_matches = [id, primary_notification_id].compact
    where(primary_notification_id: potential_id_matches).or(where(id: potential_id_matches))
  end

  def self.associated_notifications(id, primary_notification_id)
    potential_id_matches = [id, primary_notification_id].compact
    where(primary_notification_id: potential_id_matches).where.not(id: id)
      .or(where(id: primary_notification_id))
  end

  def self.bikes
    Bike.unscoped.includes(:graduated_notifications)
        .where(graduated_notifications: { id: pluck(:id) })
  end

  def active?; self.class.active_statuses.include?(status) end

  def primary_notification?; primary_notification_id.blank? end

  def secondary_notification?; !primary_notification? end

  def associated_notifications; self.class.associated_notifications(id, primary_notification_id) end

  def associated_notifications_including_self; self.class.associated_notifications_including_self(id, primary_notification_id) end

  def main_notification; primary_notification? ? self : primary_notification end

  def send_email?
    return false unless primary_notification?
    organization.deliver_graduated_notifications?
  end

  def mark_remaining!(resolved_at: nil)
    self.marked_remaining_at ||= resolved_at || Time.current
    # We don't want to re-mark remaining
    return true unless marked_remaining_at_changed?
    update(updated_at: Time.current)
    associated_notifications.each { |n| n.update(updated_at: Time.current) }
    true
  end

  def set_calculated_attributes
    self.status = calculated_status
    self.marked_remaining_link_token ||= SecurityTokenizer.new_token if pending?
    self.user ||= bike.user
    self.email ||= calculated_email
  end

  def process_notification
    # ProcessGraduatedNotificationWorker.perform_async(id)
  end

  private

  def calculated_status
    return "pending" unless main_notification.delivery_status == "email_success"
    return "marked_remaining" if marked_remaining_at.present? # Because prior to saving
    associated_notifications_including_self.marked_remaining.any? ? "marked_remaining" : "delivered"
  end

  def calculated_email
    user&.email || bike.owner_email
  end
end
