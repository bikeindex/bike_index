# This is a stub. It needs to be expanded to include all the notifications that we send to users
# (other than graduated_notifications and parking_notifications)
class Notification < ApplicationRecord
  KIND_ENUM = {
    confirmation_email: 0,
    receipt: 1,
    phone_verification: 5,
    donation_standard: 11,
    donation_second: 12,
    donation_stolen: 13,
    donation_recovered: 14,
    donation_theft_alert: 15
  }.freeze

  MESSAGE_CHANNEL_ENUM = {
    email: 0,
    text: 1
  }

  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  before_validation :set_calculated_attributes

  enum kind: KIND_ENUM
  enum message_channel: MESSAGE_CHANNEL_ENUM

  scope :email_success, -> { where(delivery_status: "email_success") }
  scope :delivered, -> { where(delivery_status: "email_success").or(where(delivery_status: "text_success")) }
  scope :undelivered, -> { where(delivery_status: nil) }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.donation_kinds
    %w[donation_standard donation_second donation_stolen donation_recovered donation_theft_alert]
  end

  # TODO: update with twilio delivery status, update scope too
  def delivered?
    email_success? || delivery_status == "text_success"
  end

  def email_success?
    delivery_status == "email_success"
  end

  def twilio_response
    return nil unless twilio_sid.present?
    TwilioIntegration.new.get_message(twilio_sid)
  end

  def set_calculated_attributes
    self.user_id ||= notifiable&.user_id
    self.delivery_status = nil if delivery_status.blank?
  end
end
