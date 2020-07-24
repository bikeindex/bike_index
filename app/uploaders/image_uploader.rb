class ImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

  def extension_white_list
    %w[jpg jpeg gif png tiff tif]
  end

  process :validate_dimensions
  process :fix_exif_rotation
  process :strip

  version :large do
    process resize_to_fit: [1200, 900]
  end

  version :medium, from_version: :large do
    process resize_to_fit: [700, 525]
  end

  version :small, from_version: :medium do
    process resize_to_fill: [300, 300]
  end
end
