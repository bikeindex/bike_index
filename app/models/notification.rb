# This is a stub. It needs to be expanded to include all the notifications that we send to users
# (other than graduated_notifications and parking_notifications)
class Notification < ApplicationRecord
  KIND_ENUM = {
    confirmation_email: 0,
    phone_verification: 5
  }.freeze

  MESSAGE_CHANNEL_ENUM = {
    email: 0,
    text: 1
  }

  belongs_to :user
  belongs_to :notifiable, polymorphic: true

  enum kind: KIND_ENUM
  enum message_channel: MESSAGE_CHANNEL_ENUM

  scope :email_success, -> { where(delivery_status: "email_success") }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def email_success?
    delivery_status == "email_success"
  end

  def twilio_response
    return nil unless twilio_sid.present?
    TwilioIntegration.get_message(twilio_sid)
  end
end
