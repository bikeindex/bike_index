# t.references :impound_record, index: true
# t.references :stolen_record, index: true
# t.references :user, index: true
# t.text :message
# t.integer :status
# t.datetime :submitted_at

class ImpoundClaim < ApplicationRecord
  STATUS_ENUM = {
    pending: 0,
    submitting: 1,
    approved: 2,
    rejected: 3,
    canceled: 4,
    retrieved: 5 # After submitted, updated by impound_record_updates
  }.freeze

  belongs_to :impound_record
  belongs_to :stolen_record
  belongs_to :user

  has_many :public_images, as: :imageable, dependent: :destroy

  validates_presence_of :impound_record_id, :user_id

  before_validation :set_calculated_attributes

  enum status: STATUS_ENUM

  scope :unsubmitted, -> { where(submitted_at: nil) }
  scope :submitted, -> { where.not(submitted_at: nil) }
  scope :active, -> { where(status: active_statuses) }
  scope :resolved, -> { where(status: inactive_statuses) }

  def self.statuses
    STATUS_ENUM.keys.map(&:to_s)
  end

  def self.resolved_statuses
    %w[rejected canceled retrieved]
  end

  def self.active_statuses
    statuses - inactive_statuses - ["pending"]
  end

  def resolved?
    self.class.resolved_statuses.include?(status)
  end

  def active?
    self.class.active_statuses.include?(status)
  end

  def bike_claimed
    impound_record&.bike
  end

  def bike_submitting
    stolen_record&.bike
  end

  # return private images too
  def bike_submitting_images
    return [] unless bike_submitting.present?
    PublicImage.unscoped.where(imageable_id: bike_submitting.id).bike.order(:listing_order)
  end

  def unsubmitted?
    submitted_at.blank?
  end

  def submitted?
    !unsubmitted?
  end

  def set_calculated_attributes
    self.status = calculated_status
    self.submitted_at ||= Time.current if status == "submitting"
    self.resolved_at ||= Time.current if resolved?
  end

  private

  def calculated_status
    status
    # impound_record_updates - maybe can influence this
    # but - impound_record&.retrieved_by_owner? doesn't solve this because we don't know if this was the owner who retrieved
  end
end
