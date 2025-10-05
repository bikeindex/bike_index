# == Schema Information
#
# Table name: stolen_notifications
#
#  id                   :integer          not null, primary key
#  kind                 :integer
#  message              :text
#  receiver_email       :string(255)
#  reference_url        :text
#  send_dates           :json
#  subject              :string(255)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  bike_id              :integer
#  doorkeeper_app_id    :bigint
#  oauth_application_id :integer
#  receiver_id          :integer
#  sender_id            :integer
#
# Indexes
#
#  index_stolen_notifications_on_doorkeeper_app_id     (doorkeeper_app_id)
#  index_stolen_notifications_on_oauth_application_id  (oauth_application_id)
#
class StolenNotification < ApplicationRecord
  KIND_ENUM = {
    stolen_permitted: 0,
    stolen_blocked: 1,
    unstolen_blocked: 2,
    unstolen_claimed_permitted: 3,
    unstolen_unclaimed_permitted: 4,
    unstolen_unclaimed_permitted_direct: 5
  }.freeze

  belongs_to :bike
  belongs_to :sender, class_name: "User", foreign_key: :sender_id
  belongs_to :receiver, class_name: "User", foreign_key: :receiver_id
  belongs_to :doorkeeper_app, class_name: "Doorkeeper::Application"

  has_many :notifications, as: :notifiable

  validates_presence_of :sender, :bike, :message

  before_validation :set_calculated_attributes
  after_create :notify_receiver

  # Kind enum was added to track how often various types of messages were sent
  # in #2275 - it isn't currently used for logic, just data analysis
  enum :kind, KIND_ENUM

  def notify_receiver
    Email::StolenNotificationJob.perform_async(id)
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
    self.receiver_email ||= bike&.contact_owner_email(sender)
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

  def mail_snippet
    return nil if doorkeeper_app_id.blank?

    MailSnippet.enabled.stolen_notification_oauth.find_by(doorkeeper_app_id:)
  end

  private

  def calculated_unstolen_blocked?
    !bike.status_stolen? && !bike.contact_owner?(sender)
  end

  def calculated_kind
    if bike.status_stolen?
      permitted_send? ? "stolen_permitted" : "stolen_blocked"
    else
      return "unstolen_blocked" unless permitted_send?

      if bike&.claimed?
        "unstolen_claimed_permitted"
      elsif bike&.current_ownership&.organization_direct_unclaimed_notifications?
        "unstolen_unclaimed_permitted_direct"
      else
        "unstolen_unclaimed_permitted"
      end
    end
  end
end
