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
    submitted: 1,
    approved: 2,
    rejected: 3,
    cancelled: 4
  }.freeze

  belongs_to :impound_record
  belongs_to :stolen_record
  belongs_to :user

  has_many :public_images, as: :imageable, dependent: :destroy

  validates_presence_of :impound_record_id, :user_id

  before_validation :set_calculated_attributes

  enum status: STATUS_ENUM

  def bike_claimed
    impound_record&.bike
  end

  # I realize the tense is wrong for pending - but meh
  def bike_submitted
    stolen_record&.bike
  end

  def set_calculated_attributes
    self.data ||= {}
    self.data[:photos] = photo_data
    self.status = calculated_status
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
