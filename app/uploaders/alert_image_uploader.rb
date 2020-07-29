class AlertImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  delegate :stolen_record, to: :model

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

  def extension_white_list
    %w[jpg jpeg gif png tiff tif]
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
      img =
        AlertImageGenerator
          .new(stolen_record: stolen_record, bike_image: img)
          .build_landscape(variant)
    end
  end

  def generate_square
    manipulate! do |img|
      img =
        AlertImageGenerator
          .new(stolen_record: stolen_record, bike_image: img)
          .build_square
    end
  end
end
