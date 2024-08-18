class ImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  def extension_allowlist
    self.class.extensions
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
