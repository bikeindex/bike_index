# == Schema Information
#
# Table name: stolen_notifications
# Database name: primary
#
#  id                :integer          not null, primary key
#  kind              :integer
#  message           :text
#  receiver_email    :string(255)
#  reference_url     :text
#  send_dates        :json
#  subject           :string(255)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  bike_id           :integer
#  doorkeeper_app_id :bigint
#  organization_id   :bigint
#  receiver_id       :integer
#  sender_id         :integer
#
# Indexes
#
#  index_stolen_notifications_on_organization_id  (organization_id)
#
class StolenNotification < ApplicationRecord
  KIND_ENUM = {
    stolen_permitted: 0,
    stolen_blocked: 1,
    unstolen_blocked: 2,
    unstolen_claimed_permitted: 3,
    unstolen_unclaimed_permitted: 4,
    unstolen_unclaimed_permitted_direct: 5,
    unstolen_organization_permitted: 6
  }.freeze

  # Kind enum was added to track how often various types of messages were sent
  # in #2275 - only unstolen_organization_permitted is used for logic (the email's copy)
  enum :kind, KIND_ENUM

  belongs_to :bike
  belongs_to :sender, class_name: "User", foreign_key: :sender_id
  belongs_to :receiver, class_name: "User", foreign_key: :receiver_id
  belongs_to :doorkeeper_app, class_name: "Doorkeeper::Application"
  belongs_to :organization, -> { with_deleted }

  has_many :notifications, as: :notifiable

  validates_presence_of :sender, :bike, :message

  before_validation :set_calculated_attributes
  after_create :notify_receiver

  def notify_receiver
    EmailJobs::StolenNotificationJob.perform_async(id)
  end

  def permitted_send?
    return false unless bike&.contact_owner?(sender)
    return true if sender.enabled?("unstolen_notifications") || doorkeeper_app_id.present?

    (sender.sent_stolen_notifications.count < 2) || sender.can_send_many_stolen_notifications
  end

  # NOTE: This is legacy. Should be updated to check notifications rather than this
  def send_dates_parsed
    return [] unless send_dates

    send_dates.is_a?(String) ? JSON.parse(send_dates) : send_dates
  end

  def set_calculated_attributes
    self.organization = sender_organization if new_record?
    # A phone registration's owner_email is the phone number
    self.receiver_email ||= (organization_message? && !bike.phone_registration?) ? bike.owner_email : bike.contact_owner_email(sender)
    self.receiver ||= bike.owner
    self.send_dates ||= [].to_json
    self.kind ||= calculated_kind
  end

  def default_message
    self.message ||= <<~STR
      Hi, this is #{sender&.name} with Bike Index.
      Is this your missing #{bike.type}?
    STR
  end

  # Stored on create - the sender's memberships and the bike's registrations can
  # change before the email sends
  def sender_organization
    new_record? ? calculated_organization : organization
  end

  # An org messaging a bike registered with it isn't reporting it stolen
  def organization_message?
    !bike.status_stolen? && sender_organization.present?
  end

  def mail_snippet
    return nil if doorkeeper_app_id.blank?

    MailSnippet.enabled.stolen_notification_oauth.find_by(doorkeeper_app_id:)
  end

  private

  # Falls back to the oldest, not Organization's default name order
  def calculated_organization
    return @calculated_organization if defined?(@calculated_organization)

    organizations = Organization.where(id: sender&.organization_roles&.select(:organization_id))
      .where(id: bike.bike_organizations.select(:organization_id)).reorder(:id).to_a
    @calculated_organization = organizations.find { it.id == organization_id } || organizations.first
  end

  def calculated_unstolen_blocked?
    !bike.status_stolen? && !bike.contact_owner?(sender)
  end

  def calculated_kind
    if bike.status_stolen?
      permitted_send? ? "stolen_permitted" : "stolen_blocked"
    else
      return "unstolen_blocked" unless permitted_send?

      if organization_message?
        "unstolen_organization_permitted"
      elsif bike&.claimed?
        "unstolen_claimed_permitted"
      elsif bike&.current_ownership&.organization_direct_unclaimed_notifications?
        "unstolen_unclaimed_permitted_direct"
      else
        "unstolen_unclaimed_permitted"
      end
    end
  end
end
