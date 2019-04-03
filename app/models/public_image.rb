class PublicImage < ActiveRecord::Base
  mount_uploader :image, ImageUploader
  # process_in_background :image, CarrierWaveProcessWorker
  belongs_to :imageable, polymorphic: true

  default_scope { where(is_private: false).order(:listing_order) }
  scope :bikes, -> { where(imageable_type: 'Bike') }

  before_save :set_calculated_attributes
  after_commit :enqueue_after_commit_jobs

  def default_name
    if imageable_type == "Bike"
      self.name = "#{imageable&.title_string} #{imageable&.frame_colors&.to_sentence}"
    elsif image
      self.name ||= File.basename(image.filename, '.*').titleize
    end
  end

  def set_calculated_attributes
    self.name = (name || default_name).truncate(100)
    return true if listing_order && listing_order > 0
    self.listing_order = imageable&.public_images&.length || 0 
  end

  def enqueue_after_commit_jobs
    if external_image_url.present? && image.blank?
      return ExternalImageUrlStoreWorker.perform_async(id)
    end
    return true unless imageable_type == 'Bike'
    AfterBikeSaveWorker.perform_async(imageable_id)
  end
end
