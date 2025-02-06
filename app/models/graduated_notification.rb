# == Schema Information
#
# Table name: graduated_notifications
#
#  id                          :bigint           not null, primary key
#  delivery_status             :string
#  email                       :string
#  marked_remaining_at         :datetime
#  marked_remaining_link_token :text
#  not_most_recent             :boolean          default(FALSE)
#  processed_at                :datetime
#  status                      :integer          default("pending")
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  bike_id                     :bigint
#  bike_organization_id        :bigint
#  marked_remaining_by_id      :bigint
#  organization_id             :bigint
#  primary_bike_id             :bigint
#  primary_notification_id     :bigint
#  user_id                     :bigint
#
# Indexes
#
#  index_graduated_notifications_on_bike_id                  (bike_id)
#  index_graduated_notifications_on_bike_organization_id     (bike_organization_id)
#  index_graduated_notifications_on_marked_remaining_by_id   (marked_remaining_by_id)
#  index_graduated_notifications_on_organization_id          (organization_id)
#  index_graduated_notifications_on_primary_bike_id          (primary_bike_id)
#  index_graduated_notifications_on_primary_notification_id  (primary_notification_id)
#  index_graduated_notifications_on_user_id                  (user_id)
#
class GraduatedNotification < ApplicationRecord
  STATUS_ENUM = {pending: 0, bike_graduated: 1, marked_remaining: 2}.freeze
  PENDING_PERIOD = 24.hours.freeze

  belongs_to :bike
  belongs_to :bike_organization
  belongs_to :user
  belongs_to :organization
  belongs_to :primary_bike, class_name: "Bike"
  belongs_to :primary_notification, class_name: "GraduatedNotification"
  belongs_to :marked_remaining_by, class_name: "User"

  has_many :secondary_notifications, class_name: "GraduatedNotification", foreign_key: :primary_notification_id

  validates_presence_of :bike_id, :organization_id, :bike_organization_id

  before_validation :set_calculated_attributes
  after_commit :update_associated_notifications, if: :persisted?

  enum :status, STATUS_ENUM

  attr_accessor :skip_update

  scope :not_most_recent, -> { where(not_most_recent: true) }
  scope :most_recent, -> { where(not_most_recent: false) }
  scope :current, -> { where(status: current_statuses) }
  scope :processed, -> { where(status: processed_statuses) }
  scope :unprocessed, -> { where(status: unprocessed_statuses) }
  scope :primary_notification, -> { where("primary_notification_id = id") }
  scope :secondary_notification, -> { where.not("primary_notification_id  = id") }
  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  def self.current_statuses
    statuses - ["marked_remaining"]
  end

  def self.processed_statuses
    %w[bike_graduated marked_remaining]
  end

  def self.unprocessed_statuses
    statuses - processed_statuses
  end

  def self.status_humanized(str)
    return nil unless str.present?
    str = str.to_s
    return "marked not graduated" if str == "marked_remaining"
    str.humanize.downcase
  end

  def self.user_or_email_query(graduated_notification)
    if graduated_notification.user_id.present?
      {user_id: graduated_notification.user_id}
    else
      {email: graduated_notification.email}
    end
  end

  def self.associated_notifications_including_self(graduated_notification)
    notification_matches = where(organization_id: graduated_notification.organization_id,
      primary_bike_id: graduated_notification.primary_bike_id)
      .where(GraduatedNotification.user_or_email_query(graduated_notification))
      .where(created_at: graduated_notification.associated_interval)
    # Don't match all graduated_notifications with blank primary_notification_id
    return notification_matches if graduated_notification.primary_notification_id.blank?
    notification_matches.or(where(primary_notification_id: graduated_notification.primary_notification_id))
  end

  def self.associated_notifications(graduated_notification)
    associated_notifications_including_self(graduated_notification)
      .where.not(id: graduated_notification.id)
  end

  def self.bikes
    Bike.unscoped.includes(:graduated_notifications)
      .where(graduated_notifications: {id: pluck(:id)})
  end

  def self.bikes_to_notify_without_notifications(organization)
    organization.bikes_not_member.includes(:graduated_notifications, :ownerships)
      .where(graduated_notifications: {id: nil})
      .where("ownerships.created_at < ?", Time.current - organization.graduated_notification_interval)
      .reorder("ownerships.created_at ASC") # Use ascending so older are processed first
  end

  def self.bikes_to_notify_expired_notifications(organization)
    organization.bikes.includes(:graduated_notifications, :ownerships)
      .where.not(graduated_notifications: {marked_remaining_at: nil})
      .where("graduated_notifications.marked_remaining_at < ?", Time.current - organization.graduated_notification_interval)
      .where(graduated_notifications: {id: pluck(:id), not_most_recent: false})
      .reorder("ownerships.created_at ASC") # Use ascending so older are processed first
  end

  def self.bike_ids_to_notify(organization)
    return Bike.nil unless organization&.graduated_notification_interval&.present?
    bikes_to_notify_without_notifications(organization).pluck(:id) +
      bikes_to_notify_expired_notifications(organization).pluck(:id)
  end

  def self.marked_remaining_by_recording_started_at
    Time.at(1681847660) # 2023-04-18 14:54 - adding this to make it easier to check whether it's pre recording or not
  end

  def message
    nil # for parity with parking_notifications
  end

  def status_humanized
    self.class.status_humanized(status)
  end

  # Get it unscoped, because we really want it
  def bike
    @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil
  end

  def primary_bike?
    bike_id == primary_bike_id
  end

  def email_success?
    delivery_status == "email_success"
  end

  # Get it unscoped, because we delete it
  def bike_organization
    bike_organization_id.present? ? BikeOrganization.unscoped.find_by_id(bike_organization_id) : nil
  end

  # Get it unscoped, because we delete it
  def user_registration_organization
    return nil if user.blank?
    UserRegistrationOrganization.unscoped.where(user_id: user_id,
      organization_id: organization_id).first
  end

  def user_display_name
    user&.display_name || email
  end

  def current?
    self.class.current_statuses.include?(status)
  end

  def processed?
    self.class.processed_statuses.include?(status)
  end

  def unprocessed?
    !processed?
  end

  def most_recent?
    !not_most_recent?
  end

  # Necessary to match parking_notification method
  def resolved?
    marked_remaining?
  end

  def primary_notification?
    id.present? && id == primary_notification_id
  end

  def secondary_notification?
    !primary_notification?
  end

  def expired?
    return false if marked_remaining_at.blank? ||
      organization.graduated_notification_interval.blank?
    marked_remaining_at < (Time.current - organization.graduated_notification_interval)
  end

  def most_recent_graduated_notification
    most_recent? ? self : matching_notifications_including_self.most_recent.last
  end

  def associated_interval
    t = created_at || Time.current
    interval = organization.graduated_notification_interval || 1.year
    (t - interval)..(t + interval)
  end

  def associated_notifications
    self.class.associated_notifications(self)
  end

  def associated_notifications_including_self
    self.class.associated_notifications_including_self(self)
  end

  # associated_notifications are notifications from the same notification period,
  # matching_notifications_including_self are notifications for the same bike, regardless of period
  def matching_notifications_including_self
    GraduatedNotification.where(bike_id: bike_id, organization_id: organization_id)
      .where(GraduatedNotification.user_or_email_query(self))
  end

  def mail_snippet
    MailSnippet.where(kind: "graduated_notification", organization_id: organization_id).first
  end

  def associated_bikes
    return Bike.none unless user.present? || bike.present?
    # We want to order the bikes by when the ownership was created, so perform that on either result
    (processed? ? bikes_from_associated_notifications : user_or_email_bikes).reorder("ownerships.created_at DESC")
  end

  def sent_at
    return nil unless email_success?
    created_at + PENDING_PERIOD
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
  def in_pending_period?
    pending_period_ends_at > Time.current
  end

  def mark_remaining!(marked_remaining_by_id: nil, skip_async: false)
    unless skip_async
      MarkGraduatedNotificationRemainingWorker.perform_in(5, id, marked_remaining_by_id)
    end
    MarkGraduatedNotificationRemainingWorker.new.perform(id, marked_remaining_by_id)
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
    return true if skip_update
    mark_previous_notifications_not_most_recent if most_recent?
    return unless primary_notification?
    self.class.associated_notifications(self)
      .each { |n| n.update(updated_at: Time.current, skip_update: true) }
  end

  def processable?
    return true if processed?
    return false unless organization.deliver_graduated_notifications?
    # The primary notification should be the first one to process, so skip processing if it isn't
    return false unless primary_notification? || primary_notification&.presence&.processed?
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

    user_registration_organization&.destroy_for_graduated_notification!
    bike_organization&.destroy!

    # deliver email before everything, so if fails, we send when we try again
    OrganizedMailer.graduated_notification(self).deliver_now if send_email?

    @skip_update = true
    update(processed_at: Time.current, delivery_status: "email_success", skip_update: true)
    return true unless primary_notification?
    # Update the associated notifications after updating the primary notification, so if we fail, they can be updated by the worker
    associated_notifications.each do |notification|
      notification.process_notification
    end
    true
  end

  def subject
    return mail_snippet.subject if mail_snippet&.subject.present?
    "Renew your #{bike&.type || "Bike"} registration with #{organization&.short_name}"
  end

  private

  def calculated_status
    # Because prior to commit, the value for the current notification isn't set
    return "marked_remaining" if marked_remaining_at.present?
    # Similar - if this is the primary_notification, we want to make sure it's marked processed during save
    (email_success? || primary_notification.present? && primary_notification.email_success?) ? "bike_graduated" : "pending"
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
    # If an associated notification was already emailed out, use that notification
    return existing_sent_notification if existing_sent_notification.present?
    return self if primary_bike? && primary_notification_id.blank? # This is the primary notification
    notifications = GraduatedNotification.where(organization_id: organization_id, bike_id: primary_bike_id)
      .where(GraduatedNotification.user_or_email_query(self))
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
    existing_notification = if organization.graduated_notification_interval.present?
      GraduatedNotification.where(created_at: potential_matching_period)
        .where(GraduatedNotification.user_or_email_query(self))
        .where(organization_id: organization_id)
        .email_success.primary_notification.first
    end
    existing_notification ||
      associated_notifications_including_self.email_success.primary_notification.first
  end

  def user_or_email_bikes
    if user_id.present?
      Bike.unscoped.current.includes(:ownerships).where(ownerships: {current: true, user_id: user_id})
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

  def previous_notifications
    matching_notifications_including_self.where("id < ?", id)
  end

  def mark_previous_notifications_not_most_recent
    previous_notifications.most_recent.update_all(not_most_recent: true)
  end
end
