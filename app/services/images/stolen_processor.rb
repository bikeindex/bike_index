# frozen_string_literal: true
require "image_processing/vips"

class Images::StolenProcessor
  PROMOTED_ALERTS_PATH = "app/assets/images/promoted_alerts"
  FACEBOOK_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "facebook-template.png")
  TWITTER_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "twitter-template.png")
  LANDSCAPE_CAPTION = Rails.root.join(PROMOTED_ALERTS_PATH, "landscape-caption.png")
  SQUARE_TEMPLATE = Rails.root.join(PROMOTED_ALERTS_PATH, "square-template.png")

  BASE_URL = ENV.fetch("BASE_URL", "bikeindex.org").gsub(/https?:\/\//, "").freeze
  # recommended sizes per facebook ads guide 2025-2-27, facebook.com/business/ads-guide/update/image
  FOUR_BY_FIVE_DIMENSIONS = [1440, 1800].freeze
  SQUARE_DIMENSIONS = [1440, 1440].freeze

  class << self
    # version :four_five # 4:5 aspect ratio, seems optimal for facebook
    # Should crop
    # recommended sizes per facebook ads guide 2025-2-27, facebook.com/business/ads-guide/update/image
    # 4:5 > 1440 x 1800
    # square > 1440 x 1440
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

    def four_by_five(image, location_text, header_height: 200, padding: 100)
      template_image = Vips::Image.new_from_file(SQUARE_TEMPLATE.to_s)

      bike_image = ImageProcessing::Vips.source(image).resize_to_fit!(
        template_image.width - padding*2,
        template_image.height - padding*2 - header_height
      )

      # Compose bike image onto alert template
      alert_image = ImageProcessing::Vips.source(template_image)
        .composite(bike_image,
          mode: :over,
          # gravity: :centre,
          offset: [padding, padding + header_height],
        ).call

      # if stolen_record_location.present?
      #   caption_image = MiniMagick::Image.open(LANDSCAPE_CAPTION).tap do |caption|
      #     caption.combine_options do |i|
      #       i.font caption_font
      #       i.fill "#FFFFFF"
      #       i.antialias
      #       i.gravity "Center"
      #       i.pointsize 50
      #       i.size "#{caption.height}x#{caption.width}"
      #       i.draw "text 0,0 '#{stolen_record_location}'"
      #     end
      #   end

      #   alert_image = alert_image.composite(caption_image) { |alert|
      #     alert.gravity "Southeast"
      #     alert.compose "Over"
      #     alert.size "x100"
      #     alert.geometry "+0+5"
      #   }
      # end
    end


    private

    def largest_dimension
      FOUR_BY_FIVE_DIMENSIONS.max
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
