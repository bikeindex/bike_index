class CircularImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  def store_dir
    "#{base_store_dir}/#{model.id}"
  end

  def base_store_dir
    "uploads/#{model.class.to_s[0, 2]}"
  end

  def filename
    "recovery_#{model.id}.png"
  end

  process :fix_exif_rotation
  process :strip # Remove EXIF data, because we don't need it
  process convert: "jpg"

  version :large do
    process :round_image
  end

  version :medium, :from_version => :large do
    process resize_to_fill: [400, 400]
  end

  version :thumb, :from_version => :medium do
    process resize_to_fill: [100, 100]
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  def round_image
    manipulate! do |img|
      path = img.path
      new_tmp_path = File.join(cache_dir, "round_#{File.basename(path)}")
      width, height = img[:dimensions]
      radius_point = ((width > height) ? [width / 2, height] : [width, height / 2]).join(",")
      imagemagick_command = ["convert",
                             "-size #{width}x#{height}",
                             "xc:transparent",
                             "-fill #{path}",
                             "-draw 'circle #{width / 2},#{height / 2} #{radius_point}'",
                             "+repage #{new_tmp_path}"].join(" ")

      system(imagemagick_command)
      MiniMagick::Image.open(new_tmp_path)
    end
  end
end
