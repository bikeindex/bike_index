class PublicImage < ActiveRecord::Base
  def self.old_attr_accessible
    %w(image name imageable listing_order remote_image_url is_private).map(&:to_sym).freeze
  end

  mount_uploader :image, ImageUploader
  # process_in_background :image, CarrierWaveProcessWorker
  belongs_to :imageable, polymorphic: true

  default_scope { where(is_private: false).order(:listing_order) }
  scope :bikes, -> { where(imageable_type: 'Bike') }

  after_create :set_order
  def set_order
    self.listing_order = imageable.public_images.length unless listing_order && listing_order > 0
  end

  def default_name
    if imageable_type == 'Bike'
      self.name = "#{imageable.title_string} #{imageable.frame_colors.to_sentence}"
    elsif image
      self.name ||= File.basename(image.filename, '.*').titleize
    end
  end

  before_save :truncate_name
  def truncate_name
    self.name = (name || default_name).truncate(100)
  end

  after_save :update_bike_listing_order
  def update_bike_listing_order
    return true unless imageable_type == 'Bike'
    AfterBikeSaveWorker.perform_async(imageable_id)
  end
end
