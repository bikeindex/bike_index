class AvatarUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  # Fallback so the page doesn't break if the image isn't there
  def default_url(*args)
    "https://files.bikeindex.org/blank.png"
  end

  process :validate_dimensions

  def extension_allowlist
    self.class.extensions
  end

  def auto_orient
    manipulate! do |img|
      img = img.auto_orient
    end
  end

  version :thumb do
    process :auto_orient
    process resize_to_fill: [100, 100]
  end

  version :medium do
    process :auto_orient
    process resize_to_fill: [300, 300]
  end

  version :large do
    process :auto_orient
    process resize_to_fill: [600, 600]
  end

  version :biggest do
    process :auto_orient
    process resize_to_fill: [1000, 1000]
  end
end
