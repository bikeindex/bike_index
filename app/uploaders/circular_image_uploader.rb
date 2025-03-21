class CircularImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  def filename
    "recovery_#{model.id}.png"
  end

  process :fix_exif_rotation
  process :strip # Remove EXIF data, because we don't need it
  process convert: "png"

  version :large do
    process :round_image
  end

  version :medium, from_version: :large do
    process resize_to_fill: [400, 400]
  end

  version :thumb, from_version: :medium do
    process resize_to_fill: [100, 100]
  end

  def extension_allowlist
    self.class.extensions
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
