class ImpoundRecord < ApplicationRecord
  # These statuses overlap with impound_record_updates
  STATUS_ENUM = { current: 0, retrieved_by_user: 1 }.freeze

  belongs_to :bike
  belongs_to :user
  belongs_to :organization

  has_one :parking_notification

  validates_presence_of :bike_id, :user_id
  validates_uniqueness_of :bike_id, if: :current?, conditions: -> { current }

  before_save :set_calculated_attributes
  after_commit :update_associations

  enum status: STATUS_ENUM

  scope :active, -> { where(status: active_statuses) }

  def self.statuses; STATUS_ENUM.keys.map(&:to_s) end

  def self.active_statuses; %w[current] end

  def self.bikes
    Bike.unscoped.includes(:impound_records)
        .where(impound_records: { id: pluck(:id) })
  end

  # Get it unscoped, because unregistered_bike notifications
  def bike; @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil end

  def current?; resolved_at.blank? end

  def resolved?; resolved_at.present? end

  def update_associations
    bike&.update_attributes(updated_at: Time.current)
  end

  def set_calculated_attributes
    self.display_id ||= calculated_display_id
    self.status = calculated_status
  end

  def last_display_id
    irs = ImpoundRecord.where(organization_id: organization_id).where.not(display_id: nil)
    irs = irs.where("id < ?", id) if id.present?
    irs.maximum(:display_id) || 0
  end

  private

  def calculated_display_id
    last_display_id + 1
  end

  def calculated_status
    resolved_at.present? ? "retrieved" : "current"
  end
end
