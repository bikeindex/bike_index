class PublicImage < ActiveRecord::Base
  attr_accessible :image, :name, :imageable, :listing_order

  mount_uploader :image, ImageUploader

  belongs_to :imageable, polymorphic: true

  default_scope order(:listing_order)

  after_create :set_order
  scope :bikes, where(imageable_type: "Bike")

  def set_order
    self.listing_order = self.imageable.public_images.length
  end

  before_create :default_name
  def default_name
    if imageable_type == "Bike"
      self.name = BikeDecorator.new(imageable).title_string
      self.name += " #{imageable.frame_colors.to_sentence}"
    else
      self.name ||= File.basename(image.filename, '.*').titleize if image
    end
  end

end
