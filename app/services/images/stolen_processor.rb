# frozen_string_literal: true
require "image_processing/vips"
require "vips"

class Images::StolenProcessor
  # Background color red rgb(239,85,110) / #ef556e
  PROMOTED_ALERTS_PATH = "app/assets/images/promoted_alerts"
  FACEBOOK_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "facebook-template.png")
  TWITTER_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "twitter-template.png")
  LANDSCAPE_CAPTION = Rails.root.join(PROMOTED_ALERTS_PATH, "landscape-caption.png")

  LANDSCAPE_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "template_landscape.png")
  SQUARE_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "template_square.png")
  FOUR_BY_FIVE_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "template_4x5.png")

  # topbar is 170px tall, right side is 120px tall
  TOPBAR_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "topbar.png")
  # topbar is 170px wide, right side is 106px wide
  TOPBAR_LANDSCAPE_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "topbar.png")
  TOPBAR_MIN_HEIGHT = 120

  BASE_URL = ENV.fetch("BASE_URL", "bikeindex.org").gsub(/https?:\/\//, "").freeze
  # recommended sizes per facebook ads guide 2025-2-27, facebook.com/business/ads-guide/update/image
  FOUR_BY_FIVE_DIMENSIONS = [1440, 1800].freeze # 4:5 aspect ratio, seems optimal for facebook
  SQUARE_DIMENSIONS = [1440, 1440].freeze
  LANDSCAPE_DIMENSIONS = [1440, 1800].freeze

  class << self
    def attach_base_image(stolen_record, image: nil)
      # This relies on existing carrierewave methods, will need to be updated
      image ||= stolen_record.bike_main_image.open_file
      processed = ImageProcessing::Vips.source(image).convert("jpg")
        .resize_to_fill(largest_dimension, largest_dimension, crop: :centre)
        .saver(strip: true).call

      stolen_record.image.attach(io: processed, filename: "#{stolen_record.id}-stolen.jpg")
      stolen_record.image.analyze

      processed
    end

    def four_by_five(image, location_text, header_height: 190, padding: 100)
      template_image = Vips::Image.new_from_file(FOUR_BY_FIVE_TEMPLATE.to_s)
      topbar_image = Vips::Image.new_from_file(TOPBAR_TEMPLATE.to_s)

      bike_image = ImageProcessing::Vips.source(image)
        .resize_to_limit(*bike_image_dimensions_for(FOUR_BY_FIVE_DIMENSIONS))
        .call(save: false) # not saving enables calculating the dimensions

      # for some reason, :centre and offset fails - so get the dimensions and manually center the image
      left_offset = (template_image.width - bike_image.width)/2
      top_offset = (template_image.height - bike_image.height)/2
      # landscape images look better vertically centered in the template. If offset is < top-bar height,
      # the image takes up the whole visible area - so use the top-bar min height. Otherwise, use the
      # offset (which vertically centers the image).
      top_offset = TOPBAR_MIN_HEIGHT if top_offset < TOPBAR_MIN_HEIGHT

      # Put bike image onto the alert template
      alert_image = ImageProcessing::Vips.source(template_image)
        .composite(bike_image,
          mode: :over,
          offset: [left_offset, top_offset],
        ).call

      # Add the topbar
      alert_image = ImageProcessing::Vips.source(alert_image)
        .composite(topbar_image,
          mode: :over,
          gravity: :north,
          offset: [0, 0],
        ).call

      # Add the location
      location_image = caption_overlay(location_text)
      ImageProcessing::Vips.source(alert_image)
        .composite(location_image,
          mode: :over,
          gravity: "south-east",
          offset: [0, 40],
        ).convert("png").call
    end

    private

    # enable passing in DPI because if the caption is too large, it should
    def caption_overlay(text, dpi: 600)
      # Add the text to the image
      text_overlay = Vips::Image.text(text, font:, dpi:)

      bg_color = [0, 0, 0] # topbar is 26, 26, 26
      text_with_bg = text_overlay.ifthenelse([255, 255, 255], bg_color, blend: true)
      bordered_text = text_with_bg.embed(
        20,                           # Left margin
        20,                           # Top margin
        text_with_bg.width + 40,      # New width (original + left + right margin)
        text_with_bg.height + 30,     # New height (original + top + bottom margin)
        background: bg_color          # Border color
      ).copy(interpretation: :srgb)   # Convert to a colorspace that can combine with the other image
    end

    def largest_dimension
      FOUR_BY_FIVE_DIMENSIONS.max
    end

    def bike_image_dimensions_for(dimensions)
      # height - topbar right height (smallest part of the black bar)
      [dimensions.first,
       dimensions.last - TOPBAR_MIN_HEIGHT]
    end

    # The font to use in the caption. Set fallbacks since different environments
    # have different fonts available.
    def font
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

    # The bike url to be displayed on the promoted alert image
    def bike_url(stolen_record)
      return if stolen_record.bike_id.blank?

      "#{BASE_URL}/bikes/#{stolen_record.bike_id}"
    end

    # The stolen location to be displayed on the promoted alert image
    # Escape single-quotes: location is passed to Imagemagick CLI inside
    # single-quotes
    def stolen_record_location(stolen_record)
      return nil unless stolen_record.to_coordinates.any?
      Geocodeable.address(stolen_record, street: false, zipcode: false, country: [:skip_default, :name])
        .gsub("'", "\\'")
    end
  end
end
