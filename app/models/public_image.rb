class PublicImage < ActiveRecord::Base
  attr_accessible :image,
    :name,
    :imageable,
    :listing_order,
    :remote_image_url,
    :is_private

  mount_uploader :image, ImageUploader
  # process_in_background :image, CarrierWaveProcessWorker

  belongs_to :imageable, polymorphic: true

  default_scope { where(is_private: false).order(:listing_order) }

  after_create :set_order
  scope :bikes, -> { where(imageable_type: "Bike") }

  def set_order
    self.listing_order = self.imageable.public_images.length
  end

  def default_name
    if imageable_type == "Bike"
      self.name = "#{imageable.title_string} #{imageable.frame_colors.to_sentence}"
    else
      self.name ||= File.basename(image.filename, '.*').titleize if image
    end
  end

  before_save :truncate_name
  def truncate_name
    self.name = (name || default_name).truncate(100)
  end

end
