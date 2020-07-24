# Note: Called "Promoted alert" on the frontend
class TheftAlert < ApplicationRecord
  enum status: {pending: 0, active: 1, inactive: 2}.freeze

  validates :theft_alert_plan,
    :status,
    :creator,
    presence: true

  validate :alert_cannot_begin_in_past_or_after_ends

  belongs_to :stolen_record
  belongs_to :theft_alert_plan
  belongs_to :payment
  belongs_to :creator,
    class_name: "User",
    foreign_key: :user_id

  scope :should_expire, -> { active.where('"theft_alerts"."end_at" <= ?', Time.current) }
  scope :creation_ordered_desc, -> { order(created_at: :desc) }

  delegate :duration_days, to: :theft_alert_plan
  delegate :country, :city, :state, :zipcode, :street, to: :stolen_record, allow_nil: true

  # Override because of recovered bikes not being in default scope
  def stolen_record
    return nil unless stolen_record_id.present?
    StolenRecord.unscoped.find_by_id(stolen_record_id)
  end

  def bike
    stolen_record&.bike
  end

  def recovered?
    stolen_record&.recovered?
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
