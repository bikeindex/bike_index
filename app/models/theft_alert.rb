class TheftAlert < ActiveRecord::Base
  enum status: { pending: 0, active: 1, inactive: 2 }.freeze

  validates :theft_alert_plan,
            :status,
            :creator,
            presence: true

  belongs_to :stolen_record
  belongs_to :theft_alert_plan
  belongs_to :payment
  belongs_to :creator,
             class_name: "User",
             foreign_key: :user_id

  scope :should_expire, -> { active.where('"theft_alerts"."end_at" <= ?', Time.current) }
  scope :creation_ordered_desc, -> { order(created_at: :desc) }

  # Override because of recovered bikes not being in default scope
  def stolen_record
    return nil unless stolen_record_id.present?
    StolenRecord.unscoped.find_by_id(stolen_record_id)
  end

  def bike; stolen_record&.bike end

  def recovered?; stolen_record&.recovered? end
end
