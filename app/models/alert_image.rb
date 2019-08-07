class AlertImage < ActiveRecord::Base
  belongs_to :stolen_record
  validates :stolen_record, presence: true

  delegate :bike, to: :stolen_record, allow_nil: true

  mount_uploader :image, AlertImageUploader
  process_in_background :image

  before_destroy -> { image.remove! }
end
