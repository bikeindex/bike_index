class PartnerUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "partner/"
  end

  def extension_white_list
    %w[jpg jpeg gif png tiff]
  end

  process :fix_exif_rotation
  process :strip

  version :large do
    process resize_to_fill: [600, 200]
  end

  version :medium, from_version: :large do
    process resize_to_fit: [300, 100]
  end

  version :small, from_version: :medium do
    process resize_to_fill: [100, 100]
  end
end
