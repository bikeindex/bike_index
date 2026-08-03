class AlertImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  delegate :stolen_record, to: :model

  def extension_allowlist
    self.class.extensions
  end

  process :fix_exif_rotation
  process :strip
  process convert: "jpg"

  version :facebook do
    process generate_landscape: :facebook
    process resize_to_fill: [1200, 630]
  end

  version :twitter do
    process generate_landscape: :twitter
    process resize_to_fill: [1200, 600]
  end

  version :square do
    process :generate_square
    process resize_to_fill: [1200, 1200]
  end

  def generate_landscape(variant)
    manipulate! do |img|
      AlertImageGenerator
        .new(stolen_record: stolen_record, bike_image: img)
        .build_landscape(variant)
    end
  end

  def generate_square
    manipulate! do |img|
      AlertImageGenerator
        .new(stolen_record: stolen_record, bike_image: img)
        .build_square
    end
  end
end
