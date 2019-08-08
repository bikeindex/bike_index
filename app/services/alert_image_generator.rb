class AlertImageGenerator
  PROMOTED_ALERTS_PATH = "app/assets/images/promoted_alerts"
  FACEBOOK_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "facebook-template.png")
  TWITTER_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "twitter-template.png")
  LANDSCAPE_CAPTION = Rails.root.join(PROMOTED_ALERTS_PATH, "landscape-caption.png")
  SQUARE_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "square-template.png")

  attr_accessor :stolen_record, :bike, :bike_image

  def initialize(stolen_record:, bike_image:)
    self.stolen_record = stolen_record
    self.bike = stolen_record.bike
    self.bike_image = bike_image
  end

  def build_landscape(variant = :facebook)
    case variant
    when :facebook
      template_image = MiniMagick::Image.open(FACEBOOK_TEMPLATE)
      banner_width = 60
      padding = 75
    when :twitter
      template_image = MiniMagick::Image.open(TWITTER_TEMPLATE)
      banner_width = 70
      padding = 75
    else
      raise ArgumentError, "unrecognized landscape variant: '#{variant}'"
    end

    # Resize bike image to fit within template dimensions
    bike_image = self.bike_image.tap do |bike|
      dimensions =
        [template_image.width - banner_width, template_image.height]
          .map { |d| d - padding }
          .join("x")

      bike.resize(dimensions)
    end

    # Compose template with bike image
    alert_image = template_image.composite(bike_image) do |alert|
      alert.gravity "Center"
      alert.compose "Over"
      # right-offset to account for LHS banner
      alert.geometry "+#{banner_width}+0"
    end

    # Compose with caption image if a location is available
    if bike_location.present?
      caption_image = MiniMagick::Image.open(LANDSCAPE_CAPTION).tap do |caption|
        caption.combine_options do |i|
          i.font caption_font
          i.fill "#FFFFFF"
          i.antialias
          i.gravity "Center"
          i.pointsize 50
          i.size "#{caption.height}x#{caption.width}"
          i.draw "text 0,0 '#{bike_location}'"
        end
      end

      alert_image = alert_image.composite(caption_image) do |alert|
        alert.gravity "Southeast"
        alert.compose "Over"
        alert.size "x100"
        alert.geometry "+0+5"
      end
    end

    alert_image
  end

  def build_square
    header_height = 100
    footer_height = 50
    padding = 200
    template_image = MiniMagick::Image.open(SQUARE_TEMPLATE)

    # Resize bike image to fit within template dimensions
    bike_image = self.bike_image.tap do |bike|
      dimensions = [
        template_image.width,
        template_image.height - header_height - footer_height,
      ].map { |dim| dim - padding }.join("x")

      bike.resize(dimensions)
    end

    # Compose bike image onto alert template
    alert_image = template_image.composite(bike_image) do |alert|
      alert.gravity "Center"
      alert.compose "Over"
      alert.geometry "+0+#{header_height - footer_height}"
    end

    alert_image.combine_options do |alert|
      alert.fill "#FFFFFF"
      alert.antialias
      alert.font caption_font

      # Overlay bike url within lower border
      if bike_url.present?
        alert.gravity "South"
        alert.pointsize 50
        alert.draw "text 0,25 '#{bike_url}'"
      end

      # Overlay bike location on RHS of top border
      if bike_location.present?
        alert.gravity "Northeast"
        alert.pointsize 110
        alert.size "x#{header_height}"
        alert.draw "text 30,30 '#{bike_location}'"
      end
    end

    alert_image
  end

  # The bike location to be displayed on the promoted alert image
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

  # The bike url to be displayed on the promoted alert image
  def bike_url
    return if bike&.id.blank?
    "bikeindex.org/bikes/#{bike.id}"
  end

  # The font to use in the caption. Set fallbacks since different environments
  # have different fonts available.
  def caption_font
    if system("mogrify -list font | grep --silent 'Font: Helvetica-Oblique$'")
      "Helvetica-Oblique"
    elsif system("mogrify -list font | grep --silent 'Font: ArialI$'")
      "ArialI"
    elsif system("mogrify -list font | grep --silent 'Font: Lato-Italic$'")
      "Lato-Italic"
    elsif system("mogrify -list font | grep --silent 'Font: DejaVu-Sans$'")
      "DejaVu-Sans"
    end
  end
end
