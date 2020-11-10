# t.references :impound_record, index: true
# t.references :stolen_record, index: true
# t.references :user, index: true
# t.text :message
# t.json :data
# t.integer :status
# t.datetime :submitted_at
class ImpoundClaim < ApplicationRecord
  STATUS_ENUM = {
    pending: 0,
    submitting: 1,
    approved: 2,
    rejected: 3,
    canceled: 4
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

  def bike_claimed
    impound_record&.bike
  end

  def bike_submitting
    stolen_record&.bike
  end

  def unsubmitted?
    submitted_at.blank?
  end

  def submitted?
    !unsubmitted?
  end

  def set_calculated_attributes
    self.data ||= {}
    self.data[:photos] = photo_data
    self.status = calculated_status
    self.submitted_at ||= Time.current if status == "submitting"
  end

  private

  def calculated_status
    return status
    # impound_record_updates - can influence this
  end

  # Because the photos may be assigned to other things. Or may change to be assigned to other things
  def photo_data
    {}
  end
end
