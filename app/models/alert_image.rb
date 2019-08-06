class AlertImage < ActiveRecord::Base
  belongs_to :stolen_record
  delegate :bike, to: :stolen_record, allow_nil: true

  mount_uploader :image, AlertImageUploader
  process_in_background :image

  scope :current, -> { where(current: true) }

  after_save :remove_image_if_retired

  def self.retire_all
    current.find_each do |alert_image|
      alert_image.update(current: false)
    end
  end

  def retired?
    !current?
  end

  private

  def remove_image_if_retired
    image.remove! if retired?
  end
end
