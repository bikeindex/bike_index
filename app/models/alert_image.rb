# == Schema Information
#
# Table name: alert_images
# Database name: primary
#
#  id               :integer          not null, primary key
#  image            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stolen_record_id :integer          not null
#
# Indexes
#
#  index_alert_images_on_stolen_record_id  (stolen_record_id)
#
# Foreign Keys
#
#  fk_rails_...  (stolen_record_id => stolen_records.id)
#
class AlertImage < ApplicationRecord
  belongs_to :stolen_record
  validates :stolen_record, presence: true

  delegate :bike, to: :stolen_record, allow_nil: true

  mount_uploader :image, AlertImageUploader
  process_in_background :image
  attr_writer :image_cache

  before_destroy -> { image.remove! }
end
