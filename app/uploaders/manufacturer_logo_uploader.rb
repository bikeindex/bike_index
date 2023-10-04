# Different from AvatarUploader because it doesn't validate extension or generate as many versions
class ManufacturerLogoUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  # Fallback so the page doesn't break if the image isn't there
  def default_url
    "https://files.bikeindex.org/blank.png"
  end

  process :validate_dimensions

  def auto_orient
    manipulate! do |img|
      img = img.auto_orient
    end
  end

  version :thumb do
    process :auto_orient
    process resize_to_fill: [100, 100]
  end
end
