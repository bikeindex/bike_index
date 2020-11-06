# t.references :impound_record, index: true
# t.references :stolen_record, index: true
# t.references :user, index: true
# t.text :serial
# t.text :bike_description
# t.text :message
class OwnershipEvidence < ApplicationRecord
  belongs_to :impound_record
  belongs_to :stolen_record
  belongs_to :user

  has_many :public_images, as: :imageable, dependent: :destroy

  validates_presence_of :impound_record_id, :user_id

  # Maybe it's going to be an actual relation someday! consistent accessor
  def impound_record_bike
    impound_record&.bike
  end

  # Maybe it's going to be an actual relation someday! consistent accessor
  def stolen_record_bike
    stolen_record&.bike
  end
end
