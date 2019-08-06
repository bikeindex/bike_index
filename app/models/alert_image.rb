class AlertImage < ActiveRecord::Base
  belongs_to :stolen_record
  delegate :bike, to: :stolen_record, allow_nil: true

  mount_uploader :image, AlertImageUploader
  process_in_background :image

  scope :current, -> { where(retired_at: nil) }

  after_save :remove_image_if_retired

  def self.retire_all
    current.find_each(&:retired!)
  end

  def retired?
    retired_at.present?
  end

  def retired!
    update(retired_at: Time.current)
  end

  private

  def remove_image_if_retired
    image.remove! if retired?
  end
end
