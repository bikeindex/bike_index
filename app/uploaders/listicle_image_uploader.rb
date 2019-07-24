class ListicleImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

  process :fix_exif_rotation
  process :strip # Remove EXIF data, because we don't need it

  version :at_width do
    process resize_to_fit: [726, 10000]
  end

  version :large, :from_version => :at_width do
    process :crop
  end

  version :medium, :from_version => :large do
    process resize_to_fill: [300, 300]
  end

  version :thumb, :from_version => :medium do
    process resize_to_fill: [100, 100]
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
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
