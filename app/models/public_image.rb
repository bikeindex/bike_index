class PublicImage < ActiveRecord::Base
  attr_accessible :image, :name, :imageable, :listing_order

  mount_uploader :image, ImageUploader

  belongs_to :imageable, polymorphic: true

  before_create :default_name

  default_scope order(:listing_order)

  after_create :set_order
  

  def set_order
    self.listing_order = self.imageable.public_images.length
  end

  def default_name
    self.name ||= File.basename(image.filename, '.*').titleize if image
  end

end
