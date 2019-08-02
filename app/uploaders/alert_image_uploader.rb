class AlertImageUploader < ApplicationUploader
  include CarrierWave::MiniMagick
  include ::CarrierWave::Backgrounder::Delay

  alias stolen_record model
  delegate :bike, to: :stolen_record

  def store_dir
    "#{base_store_dir}/#{stolen_record.id}"
  end

  def base_store_dir
    "uploads/#{stolen_record.class.to_s[0, 2]}"
  end

  def extension_white_list
    %w(jpg jpeg gif png tiff tif)
  end

  # The bike url to be displayed on the premium alert image
  def bike_url
    "bikeindex.org/bikes/#{bike.id}"
  end

  # The bike location to be displayed on the premium alert image
  def bike_location
    location =
      if stolen_record.address_location.present?
        stolen_record.address_location
      else
        bike.registration_location
      end

    # escape single-quotes: location is passed to Imagemagick CLI inside
    # single-quotes
    location.gsub("'", "\\'")
  end

  process :fix_exif_rotation
  process :strip
  process convert: "jpg"

  version :landscape do
    process :generate_landscape
    process resize_to_fill: [1200, 630]
  end

  version :square do
    process :generate_square
    process resize_to_fill: [1200, 1200]
  end

  def generate_landscape
    Rails.logger.info "Processing #{current_path}"

    premium_alerts_path = "app/assets/images/promoted_alerts"
    base_template_path = Rails.root.join(premium_alerts_path, "landscape-template.png")
    caption_template_path = Rails.root.join(premium_alerts_path, "landscape-caption.png")
    banner_width = 60
    padding = 75

    manipulate! do |img|
      template = MiniMagick::Image.open(base_template_path)
      width = template.width - banner_width
      height = template.height

      bike = img.tap { |i| resize_bike_image(i, width, height, padding) }

      alert_image =
        template
          .composite(bike) { |i| compose_bike_image(i, banner_width) }

      if bike_location.present?
        caption =
          MiniMagick::Image
            .open(caption_template_path)
            .tap { |image| image.combine_options { |i| format_caption(i, bike_location, image) } }

        alert_image = alert_image.composite(caption) { |i| compose_caption(i) }
      end

      img = alert_image
    end

    Rails.logger.info "Finished processing #{current_path}"
  end

  def generate_square
    Rails.logger.info "Processing #{current_path}"

    premium_alerts_path = "app/assets/images/promoted_alerts"
    base_template_path = Rails.root.join(premium_alerts_path, "square-template.png")

    header_height = 100
    footer_height = 50
    padding = 200

    manipulate! do |img|
      template = MiniMagick::Image.open(base_template_path)
      container_width = template.width
      container_height = template.height - header_height - footer_height

      bike = img.tap do |b|
        dimensions =
          [container_width, container_height]
            .map { |dim| dim - padding }
            .join("x")

        b.resize(dimensions)
      end

      alert_image = template.composite(bike) do |c|
        c.gravity "Center"
        c.compose "Over"
        c.geometry "+0+#{header_height - footer_height}"
      end

      alert_image.combine_options do |i|
        i.fill "#FFFFFF"
        i.antialias
        i.font caption_font

        # Overlay bike url within lower border
        i.gravity "South"
        i.pointsize 50
        i.draw "text 0,25 '#{bike_url}'"

        # Overlay bike location on RHS of top border
        i.gravity "Northeast"
        i.pointsize 110
        i.size "x#{header_height}"
        i.draw "text 30,30 '#{bike_location}'"
      end

      img = alert_image
    end

    Rails.logger.info "Finished processing #{current_path}"
  end

  def caption_font
    if system("mogrify -list font | grep --silent 'Font: Helvetica-Oblique$'")
      "Helvetica-Oblique"
    elsif system("mogrify -list font | grep --silent 'Font: ArialI$'")
      "ArialI"
    elsif system("mogrify -list font | grep --silent 'Font: DejaVu-Sans$'")
      "DejaVu-Sans"
    end
  end
end

def format_caption(image, text, container)
  image.font "ArialI"
  image.fill "#FFFFFF"
  image.antialias
  image.gravity "Center"
  image.pointsize 50
  image.size [container.height, container.width].join("x")
  image.draw "text 0,0 '#{text}'"
end

def compose_bike_image(image, banner_width)
  image.gravity "Center"
  image.compose "Over"
  # right-offset to account for LHS banner
  image.geometry "+#{banner_width}+0"
end

def compose_caption(image)
  image.gravity "Southeast"
  image.compose "Over"
  image.size [nil, 100].join("x")
  image.geometry "+0+5"
end

def resize_bike_image(image, container_width, container_height, padding)
  dimensions =
    [container_width, container_height]
      .map { |d| d - padding }
      .join("x")

  image.resize(dimensions)
end
