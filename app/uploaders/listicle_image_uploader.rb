class ListicleImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  process :fix_exif_rotation
  process :strip # Remove EXIF data, because we don't need it

  version :at_width do
    process resize_to_fit: [726, 10000]
  end

  version :large, from_version: :at_width do
    process :crop
  end

  version :medium, from_version: :large do
    process resize_to_fill: [300, 300]
  end

  version :thumb, from_version: :medium do
    process resize_to_fill: [100, 100]
  end

  def extension_allowlist
    self.class.extensions
  end

  def crop
    # resize_to_fit(726, 10000)
    manipulate! do |img|
      x = 0
      y = model.crop_top_offset.to_i
      w = 726
      h = 450
      img.crop "#{w}x#{h}+#{x}+#{y}"
      img
    end
  end
end
