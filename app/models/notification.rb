# TODO: combine all the notification models - or subclass? Or create Notifications for each?
# - graduated_notifications
# - parking_notifications

class Notification < ApplicationRecord
  KIND_ENUM = {
    confirmation_email: 0,
    receipt: 1,
    stolen_notification: 3,
    phone_verification: 5,
    donation_standard: 11,
    donation_second: 12,
    donation_stolen: 13,
    donation_recovered: 14,
    donation_theft_alert: 15,
    impound_claim_submitting: 16,
    impound_claim_approved: 17,
    impound_claim_denied: 18,
    theft_alert_recovered: 19,
    theft_alert_posted: 20,
    stolen_contact: 21,
    stolen_twitter_alerter: 2,
    bike_possibly_found: 23,
    user_alert_theft_alert_without_photo: 24,
    user_alert_stolen_bike_without_location: 25
  }.freeze

  MESSAGE_CHANNEL_ENUM = {
    email: 0,
    text: 1
  }.freeze

  belongs_to :user
  belongs_to :bike
  belongs_to :notifiable, polymorphic: true

  before_validation :set_calculated_attributes

  enum kind: KIND_ENUM
  enum message_channel: MESSAGE_CHANNEL_ENUM

  scope :email_success, -> { where(delivery_status: "email_success") }
  scope :delivered, -> { where(delivery_status: "email_success").or(where(delivery_status: "text_success")) }
  scope :undelivered, -> { where(delivery_status: nil) }
  scope :with_bike, -> { where.not(bike_id: nil) }
  scope :without_bike, -> { where(bike_id: nil) }
  scope :donation, -> { where(kind: donation_kinds) }
  scope :theft_alert, -> { where(kind: theft_alert_kinds) }
  scope :impound_claim, -> { where(kind: impound_claim_kinds) }
  scope :customer_contact, -> { where(kind: customer_contact_kinds) }

  def self.kinds
    KIND_ENUM.keys.map(&:to_s)
  end

  def self.donation_kinds
    kinds.select { |k| k.start_with?("donation_") }.freeze
  end

  def self.theft_alert_kinds
    kinds.select { |k| k.start_with?("theft_alert_") }.freeze
  end

  def self.impound_claim_kinds
    kinds.select { |k| k.start_with?("impound_claim_") }.freeze
  end

  def self.user_alert_kinds
    kinds.select { |k| k.start_with?("user_alert_") }.freeze
  end

  def self.customer_contact_kinds
    %w[stolen_contact stolen_twitter_alerter bike_possibly_found].freeze
  end

  def self.sender_auto_kinds
    donation_kinds + theft_alert_kinds + %w[stolen_twitter_alerter bike_possibly_found]
  end

  # TODO: update with twilio delivery status, update scope too
  def delivered?
    email_success? || delivery_status == "text_success"
  end

  def email_success?
    delivery_status == "email_success"
  end

  def theft_alert?
    self.class.theft_alert_kinds.include?(kind)
  end

  def donation?
    self.class.donation_kinds.include?(kind)
  end

  def impound_claim?
    self.class.impound_claim_kinds.include?(kind)
  end

  def customer_contact?
    self.class.customer_contact_kinds.include?(kind)
  end

  def calculated_email
    return user&.email if user.present?
    notifiable&.user_email if customer_contact?
  end

  def twilio_response
    return nil unless twilio_sid.present?
    TwilioIntegration.new.get_message(twilio_sid)
  end

  def notifiable_display_name
    return nil if notifiable.blank?
    "#{notifiable.class.to_s.titleize} ##{notifiable_id}"
  end

  def sender
    return nil if self.class.sender_auto_kinds.include?(kind)
    if notifiable_type == "CustomerContact"
      notifiable&.creator
    elsif impound_claim?
      notifiable&.user
    end
  end

  def sender_display_name
    return "auto" if self.class.sender_auto_kinds.include?(kind)
    sender&.display_name
  end

  def set_calculated_attributes
    self.user_id ||= notifiable&.user_id
    self.delivery_status = nil if delivery_status.blank?
  end
end
