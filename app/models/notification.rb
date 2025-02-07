# == Schema Information
#
# Table name: notifications
#
#  id                     :bigint           not null, primary key
#  delivery_errors        :text
#  delivery_status        :integer
#  delivery_status_str    :string
#  kind                   :integer
#  message_channel        :integer          default("email")
#  message_channel_target :string
#  notifiable_type        :string
#  twilio_sid             :text
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  bike_id                :bigint
#  notifiable_id          :bigint
#  user_id                :bigint
#
# Indexes
#
#  index_notifications_on_bike_id                            (bike_id)
#  index_notifications_on_notifiable_type_and_notifiable_id  (notifiable_type,notifiable_id)
#  index_notifications_on_user_id                            (user_id)
#

class Notification < ApplicationRecord
  # TODO: create notifications for every email we send (including other models, e.g. Feedback)
  #
  # Every single notification that we send has a separate enum key - which is a lot!
  # so put that list in a YAML file for increased legibility
  KIND_ENUM = YAML.load_file(Rails.root.join("config/notification_kinds_enums.yml")).freeze

  MESSAGE_CHANNEL_ENUM = {email: 0, text: 1}.freeze
  DELIVERY_STATUS_ENUM = {delivery_pending: 0, delivery_success: 1, delivery_failure: 2}.freeze

  belongs_to :user # RECEIVER of the notification - unless it's a stolen_notification_blocked, which is sent to admin instead
  belongs_to :bike
  belongs_to :notifiable, polymorphic: true

  before_validation :set_calculated_attributes

  enum :kind, KIND_ENUM
  enum :message_channel, MESSAGE_CHANNEL_ENUM
  enum :delivery_status, DELIVERY_STATUS_ENUM

  scope :email_success, -> { where(delivery_status_str: "email_success") }
  scope :delivered, -> { where(delivery_status_str: "email_success").or(where(delivery_status_str: "text_success")) }
  scope :undelivered, -> { where(delivery_status_str: nil) }
  scope :with_bike, -> { where.not(bike_id: nil) }
  scope :without_bike, -> { where(bike_id: nil) }
  scope :donation, -> { where(kind: donation_kinds) }
  scope :theft_alert, -> { where(kind: theft_alert_kinds) }
  scope :impound_claim, -> { where(kind: impound_claim_kinds) }
  scope :customer_contact, -> { where(kind: customer_contact_kinds) }
  scope :theft_survey, -> { where(kind: theft_survey_kinds) }
  scope :admin, -> { where(kind: admin_kinds) }

  class << self
    def kinds
      KIND_ENUM.keys.map(&:to_s)
    end

    def kind_humanized(str)
      return "" unless str.present?
      str.tr("_", " ")
    end

    def donation_kinds
      kinds.select { |k| k.start_with?("donation_") }.freeze
    end

    def theft_alert_kinds
      kinds.select { |k| k.start_with?("theft_alert_") }.freeze
    end

    def impound_claim_kinds
      kinds.select { |k| k.start_with?("impound_claim_") }.freeze
    end

    def stolen_notification_kinds
      kinds.select { |k| k.start_with?("stolen_notification_") }.freeze
    end

    def user_alert_kinds
      kinds.select { |k| k.start_with?("user_alert_") }.freeze
    end

    def theft_survey_kinds
      %w[theft_survey_4_2022 theft_survey_2023].freeze
    end

    def b_param_kinds
      %w[partial_registration].freeze
    end

    def customer_contact_kinds
      %w[stolen_contact stolen_twitter_alerter bike_possibly_found].freeze
    end

    def pos_integration_broken_kinds
      # TODO: Send Lightspeed notifications from here
      %w[invalid_extension_for_ascend_import].freeze
    end

    def admin_kinds
      %w[stolen_notification_blocked unknown_organization_for_ascend].freeze +
        pos_integration_broken_kinds
    end

    def sender_auto_kinds
      donation_kinds + theft_alert_kinds + user_alert_kinds + pos_integration_broken_kinds +
        %w[bike_possibly_found stolen_twitter_alerter unknown_organization_for_ascend]
    end

    def search_message_channel_target(str)
      return none unless str.present?
      where("message_channel_target ILIKE ?", "%#{str.strip.downcase}%")
    end

    def notifications_sent_or_received_by(user_or_id)
      user_id = user_or_id.is_a?(User) ? user_or_id.id : user_or_id
      # TODO: THIS IS SHITTY
      customer_contact_ids = CustomerContact.where(creator_id: user_id).pluck(:id)
      stolen_notification_ids = StolenNotification.where(sender: user_id).pluck(:id)

      where(user_id: user_id)
        .or(where(notifiable_type: "CustomerContact", notifiable_id: customer_contact_ids))
        .or(where(notifiable_type: "StolenNotification", notifiable_id: stolen_notification_ids))
    end

    def delivery_status_from_str(delivery_status_str)
      if delivery_status_str.blank?
        :delivery_pending
      elsif delivery_status_str.match?("_success")
        :delivery_success
      else
        :delivery_failure
      end
    end
  end

  # TODO: update with twilio delivery status, update scope too
  def delivered?
    email_success? || delivery_status_str == "text_success"
  end

  def email_success?
    delivery_status_str == "email_success"
  end

  def theft_alert?
    self.class.theft_alert_kinds.include?(kind)
  end

  def b_param?
    self.class.b_param_kinds.include?(kind)
  end

  def stolen_notification?
    self.class.stolen_notification_kinds.include?(kind)
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

  def theft_survey?
    self.class.theft_survey_kinds.include?(kind)
  end

  def kind_humanized
    self.class.kind_humanized(kind)
  end

  def twilio_response
    return nil unless twilio_sid.present?
    Integrations::Twilio.new.get_message(twilio_sid)
  end

  def notifiable_display_name
    return nil if notifiable.blank?
    "#{notifiable.class.to_s.titleize} ##{notifiable_id}"
  end

  # Update notifications_sent_or_received_by if changing
  def sender
    return nil if self.class.sender_auto_kinds.include?(kind)
    if notifiable_type == "CustomerContact"
      notifiable&.creator
    elsif notifiable_type == "StolenNotification"
      notifiable&.sender
    elsif impound_claim?
      notifiable&.user
    end
  end

  def sender_display_name
    return "auto" if self.class.sender_auto_kinds.include?(kind)
    sender&.display_name
  end

  def set_calculated_attributes
    self.user_id ||= calculated_user_id
    self.bike_id ||= notifiable.bike_id if defined?(notifiable.bike_id)
    self.delivery_status_str = nil if delivery_status_str.blank?
    self.delivery_status = self.class.delivery_status_from_str(delivery_status_str)
    self.message_channel_target ||= calculated_message_channel_target if delivery_status_str.present?
  end

  def survey_id
    raise "Not a theft survey!" unless theft_survey?
    id_searched = id || self.class.where(kind: kind).maximum(:id)
    self.class.where(kind: kind).where("id < ?", id_searched).count + 1
  end

  def bike_with_fallback
    return nil if bike_id.blank?
    bike || Bike.unscoped.find_by_id(bike_id)
  end

  def calculated_message_channel_target
    return calculated_phone if message_channel == "text" || phone_verification?
    calculated_email
  end

  # This method takes a block
  def track_email_delivery
    yield

    update(delivery_status_str: "email_success")
  end

  private

  def calculated_phone
    notifiable&.phone
  end

  def calculated_email
    c_email = notifiable&.email if b_param? || notifiable_type == "Payment"
    c_email ||= notifiable&.receiver_email if stolen_notification?
    c_email ||= user&.email if user_id.present?
    c_email ||= notifiable&.user_email if customer_contact?
    c_email ||= bike_with_fallback&.owner_email
    c_email
  end

  def calculated_user_id
    return notifiable&.receiver_id if notifiable_type == "StolenNotification"
    notifiable&.user_id if defined?(notifiable.user_id)
  end
end
