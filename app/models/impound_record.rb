class ImpoundRecord < ApplicationRecord
  # These statuses overlap with impound_record_updates
  STATUS_ENUM = {current: 0, retrieved_by_owner: 2, removed_from_bike_index: 3, transferred_to_new_owner: 4}.freeze

  belongs_to :bike
  belongs_to :user
  belongs_to :organization
  belongs_to :location

  has_one :parking_notification
  has_many :impound_record_updates

  validates_presence_of :bike_id, :user_id
  validates_uniqueness_of :bike_id, if: :current?, conditions: -> { current }

  before_save :set_calculated_attributes
  after_commit :update_associations

  enum status: STATUS_ENUM

  scope :active, -> { where(status: active_statuses) }

  attr_accessor :skip_update

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  def self.active_statuses
    %w[current]
  end

  def self.resolved_statuses
    statuses - active_statuses
  end

  def self.statuses_humanized
    ImpoundRecordUpdate.kinds_humanized
  end

  def self.statuses_humanized_short
    ImpoundRecordUpdate.kinds_humanized_short
  end

  def self.bikes
    Bike.unscoped.includes(:impound_records)
      .where(impound_records: {id: pluck(:id)})
  end

  # Get it unscoped, because unregistered_bike notifications
  def bike
    @bike ||= bike_id.present? ? Bike.unscoped.find_by_id(bike_id) : nil
  end

  def creator
    parking_notification&.user
  end

  def active?
    self.class.active_statuses.include?(status)
  end

  def resolved?
    !active?
  end

  def resolving_update
    impound_record_updates.resolved.order(:id).first
  end

  def status_humanized
    self.class.statuses_humanized[status.to_sym]
  end

  def status_humanized_short
    self.class.statuses_humanized_short[status.to_sym]
  end

  def update_kinds
    organization.enabled?("impound_bikes_locations") ? ImpoundRecordUpdate.kinds : ImpoundRecordUpdate.kinds_without_location
  end

  def update_associations
    # We call this job inline in ProcessParkingNotificationWorker
    return true if skip_update
    ImpoundUpdateBikeWorker.perform_async(id)
  end

  def set_calculated_attributes
    self.display_id ||= calculated_display_id
    self.status = calculated_status
    self.resolved_at = resolving_update&.created_at
    self.location_id = calculated_location_id
    self.user_id = calculated_user_id
  end

  def last_display_id
    irs = ImpoundRecord.where(organization_id: organization_id).where.not(display_id: nil)
    irs = irs.where("id < ?", id) if id.present?
    irs.maximum(:display_id) || 0
  end

  private

  def calculated_display_id
    default_display_id = last_display_id + 1
    return default_display_id unless ImpoundRecord.where(organization_id: organization_id, display_id: default_display_id)
    ImpoundRecord.where(organization_id: organization_id).maximum(:display_id).to_i + 1
  end

  def calculated_status
    return resolving_update.kind if resolving_update.present?
    "current"
  end

  def calculated_location_id
    # Return the existing location_id if the organization doesn't have locations enabled - just to be safe and not lose data
    return location_id unless organization.enabled?("impound_bikes_locations")
    # If any impound records have a set location, use that, otherwise, use the default location
    impound_record_updates.with_location.order(:id).last&.location_id || organization.default_impound_location&.id
  end

  def calculated_user_id
    return user_id unless impound_record_updates.where.not(user_id: nil).any?
    impound_record_updates.where.not(user_id: nil).reorder(:id).last&.user_id
  end
end
