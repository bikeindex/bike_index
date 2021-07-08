# Note: Called "Promoted alert" on the frontend
class TheftAlert < ApplicationRecord
  STATUS_ENUM = {pending: 0, active: 1, inactive: 2}.freeze

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
  scope :creation_ordered_desc, -> { order(created_at: :desc) }

  delegate :duration_days, :duration_days_facebook, :amount_facebook, :amount_cents_facebook,
    :ad_radius_miles, to: :theft_alert_plan
  delegate :country, :city, :state, :zipcode, :street, to: :stolen_record, allow_nil: true

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  # Override because of recovered bikes not being in default scope
  def stolen_record
    return nil unless stolen_record_id.present?
    StolenRecord.current_and_not.find_by_id(stolen_record_id)
  end

  def bike
    stolen_record&.bike
  end

  def paid?
    payment&.paid? || false
  end

  def activateable?
    !missing_photo? && !missing_location? && paid?
  end

  def recovered?
    stolen_record&.recovered?
  end

  def missing_location?
    latitude.blank? && longitude.blank?
  end

  def missing_photo?
    !stolen_record&.current_alert_image.present?
  end

  def facebook_name(kind = "campaign")
    n = "Theft Alert #{id} - #{amount_facebook}"
    return n if kind == "campaign"
    "#{n} - #{kind}"
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
