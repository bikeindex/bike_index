# Note: Called "Promoted alert" on the frontend
class TheftAlert < ApplicationRecord
  STATUS_ENUM = {pending: 0, active: 1, inactive: 2}.freeze
  # Timestamp for when notification functionality was added
  NOTIFY_AFTER = 1625757882 # 2021-7-8

  enum status: STATUS_ENUM

  validates :theft_alert_plan,
    :status,
    :user_id,
    presence: true

  validate :alert_cannot_begin_in_past_or_after_ends

  belongs_to :stolen_record
  belongs_to :theft_alert_plan
  belongs_to :payment
  belongs_to :user

  has_many :notifications, as: :notifiable

  before_validation :set_calculated_attributes

  scope :should_expire, -> { active.where('"theft_alerts"."end_at" <= ?', Time.current) }
  scope :paid, -> { where.not(payment_id: nil) }
  scope :posted, -> { where.not(begin_at: nil) }
  scope :creation_ordered_desc, -> { order(created_at: :desc) }
  scope :facebook_updateable, -> { where("(facebook_data -> 'campaign_id') IS NOT NULL") }
  scope :should_update_facebook, -> { facebook_updateable.where("theft_alerts.end_at > ?", update_end_buffer) }

  delegate :duration_days, :duration_days_facebook, :ad_radius_miles, to: :theft_alert_plan
  delegate :country, :city, :state, :zipcode, :street, to: :stolen_record, allow_nil: true

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  def self.update_end_buffer
    Time.current - 2.days
  end

  # Override because of recovered bikes not being in default scope
  def stolen_record
    return nil unless stolen_record_id.present?
    StolenRecord.current_and_not.find_by_id(stolen_record_id)
  end

  def bike
    stolen_record&.bike
  end

  def notify?
    return false if facebook_data.blank? || facebook_data&.dig("no_notify").present?
    stolen_record.present? && stolen_record.receive_notifications?
  end

  def paid?
    payment&.paid? || false
  end

  def live?
    posted? && facebook_data&.dig("effective_object_story_id").present? &&
      end_at > Time.current
  end

  # Active or has been active
  def posted?
    begin_at.present?
  end

  def facebook_updateable?
    campaign_id.present?
  end

  def should_update_facebook?
    return false unless facebook_updateable?
    return false if end_at < self.class.update_end_buffer
    facebook_updated_at.blank? || facebook_updated_at < Time.current - 6.hours
  end

  # literally CAN NOT activate
  def activateable_except_approval?
    !missing_photo? && !missing_location? && paid?
  end

  # Probably don't want to activate
  def activateable?
    activateable_except_approval? && stolen_record_approved?
  end

  def activating?
    pending? && activating_at.present?
  end

  def recovered?
    stolen_record&.recovered?
  end

  def missing_location?
    latitude.blank? && longitude.blank?
  end

  def stolen_record_approved?
    stolen_record&.approved? || false
  end

  def missing_photo?
    !stolen_record&.current_alert_image.present?
  end

  def facebook_name(kind = "campaign")
    n = "Theft Alert #{id} - #{amount_facebook}"
    return n if kind == "campaign"
    "#{n} - #{kind}"
  end

  def amount_cents_facebook
    return facebook_data["amount_cents"] if facebook_data&.dig("amount_cents").present?
    theft_alert_plan&.amount_cents_facebook
  end

  def amount_facebook
    MoneyFormater.money_format(amount_cents_facebook)
  end

  def activating_at
    t = facebook_data&.dig("activating_at")
    t.present? ? TimeParser.parse(t) : nil
  end

  def facebook_post_url
    return nil unless facebook_data&.dig("effective_object_story_id").present?
    "https://facebook.com/#{facebook_data&.dig("effective_object_story_id")}"
  end

  def campaign_id
    facebook_data&.dig("campaign_id")
  end

  def adset_id
    facebook_data&.dig("adset_id")
  end

  def ad_id
    facebook_data&.dig("ad_id")
  end

  def engagement
    facebook_data&.dig("engagement") || {}
  end

  def ad_radius_miles
    25
  end

  def message
    "#{stolen_record&.city}: Keep an eye out for this stolen #{bike.mnfg_name}. If you see it, let the owner know on Bike Index!"
  end

  def calculated_begin_at
    begin_at.present? ? begin_at : Time.current
  end

  # Default to 3 days, because something
  def calculated_end_at
    calculated_begin_at + (duration_days_facebook || 3).days
  end

  def set_calculated_attributes
    if stolen_record&.latitude.present?
      self.latitude = stolen_record.latitude
      self.longitude = stolen_record.longitude
    end
    self.bike_id = stolen_record&.bike_id
  end

  private

  def alert_cannot_begin_in_past_or_after_ends
    return if begin_at.blank? && end_at.blank?

    if begin_at.blank?
      errors.add(:begin_at, :must_be_present)
    elsif end_at.blank?
      errors.add(:end_at, :must_be_present)
    elsif begin_at >= end_at
      errors.add(:end_at, :must_be_later_than_start_time)
    end
  end
end
