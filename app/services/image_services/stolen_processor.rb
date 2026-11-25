# frozen_string_literal: true

require "image_processing/vips"
require "vips"

module ImageServices
  module StolenProcessor
    extend Functionable

    PROMOTED_ALERTS_PATH = "app/assets/images/promoted_alerts"
    # 4:5 and square are the recommended sizes per facebook ads guide 2025-2-27
    # facebook.com/business/ads-guide/update/image - 4:5 seems like the preferred
    TEMPLATE_CONFIG = {
      four_by_five: {topbar: :horizontal, dimensions: [1440, 1800]},
      square: {topbar: :horizontal, dimensions: [1440, 1440]},
      opengraph: {topbar: :vertical, dimensions: [1200, 630]}
    }.freeze

    # topbar is 170px tall, right side is 120px tall - so the minimum height is 120
    TOPBAR_HORIZONTAL_HEIGHT = 120
    # topbar vertical is 82px wide, right side is 106px wide
    # ... It looks better when the image doesn't overlap with the bar
    TOPBAR_VERTICAL_WIDTH = 190

    # NOTE: This doesn't delete images - that's handled by BikeJobs::RemoveOrphanedImagesJob

    # Previously, we would set the image via passing it. That's a pain to track!
    # Instead, when overriding the image in admin, let's update the image we're overriding with
    # and make it the first image
    def update_alert_images(stolen_record, force_regenerate: false, public_image_id: nil)
      image, image_id = image_and_id(stolen_record, public_image_id)

      stolen_record.skip_update = true
      if image.present?
        return if !force_regenerate && stolen_record.images_attached_id == image_id

        # Prevent touching the stolen record, which kicks off a job
        ActiveRecord::Base.no_touching do
          attach_images(stolen_record, image, stolen_record_location(stolen_record))
          stamp(stolen_record.image_four_by_five.blob, "image_id" => image_id).save
        end
      elsif (existing_blob = stolen_record.image_four_by_five&.blob)
        stamp(existing_blob, "removed" => true)
        # We don't want to update the bike.updated_at unless this is a change
        return unless existing_blob.changed?

        existing_blob.save
      end
      stolen_record.bike&.update(updated_at: Time.current)
      stolen_record
    ensure
      # Tempfiles need close! or they sit in /tmp until GC; a local carrierwave File is the
      # stored image itself, so only close it
      image.respond_to?(:close!) ? image.close! : image&.close
    end

    #
    # private below here
    #

    def image_and_id(stolen_record, public_image_id)
      if public_image_id.present?
        public_image = PublicImage.unscoped.find_by_id(public_image_id)
      elsif use_stolen_images_override_id?(stolen_record)
        # Image ID is overridden, use the assigned ID
        return image_and_id(stolen_record, stolen_record.images_attached_id)
      end
      public_image ||= stolen_record.bike_main_image
      image = public_image&.open_file
      return [image, public_image.id] if image.present?

      stock_photo_url = Bike.unscoped.find_by(id: stolen_record.bike_id)&.stock_photo_url
      if stock_photo_url.present?
        [Down.download(stock_photo_url), "b#{stolen_record.bike_id}"]
      else
        [nil, nil]
      end
    end

    # If the existing attached image was created after the bike's public images were updated
    # use the existing public image (it was assigned manually)
    def use_stolen_images_override_id?(stolen_record)
      images_updated = PublicImage.unscoped.where(imageable_type: "Bike", imageable_id: stolen_record.bike_id).maximum(:updated_at)
      return false if images_updated.blank? || stolen_record.image_four_by_five&.blob&.created_at.blank? ||
        stolen_record.images_attached_id.blank? # nothing recorded the image it came from

      stolen_record.image_four_by_five.blob.created_at > images_updated
    end

    # stolen_record_id is how BikeJobs::RemoveOrphanedImagesJob finds these - a superseded alert
    # stays unattached (dependent: false) until it collects them
    def attach_images(stolen_record, image, location_text)
      four_by_five = create_alert_blob(stolen_record, :four_by_five, image, location_text)
      square = create_alert_blob(stolen_record, :square, image, location_text)
      opengraph = create_alert_blob(stolen_record, :opengraph, image, location_text)

      stolen_record.image_square.attach(square)
      stolen_record.image_opengraph.attach(opengraph)
      # Attach 4 by five last, it's what sets images_attached?
      stolen_record.image_four_by_five.attach(four_by_five)
    end

    # create_and_upload! takes explicit keywords, so the stamp is a second write
    def create_alert_blob(stolen_record, template, image, location_text)
      ActiveStorage::Blob.create_and_upload!(
        io: generate_alert(template:, image:, location_text:),
        filename: "stolen-#{stolen_record.id}-#{template}.jpeg"
      ).tap { stamp(it, "stolen_record_id" => stolen_record.id).save! }.tap(&:analyze)
    end

    # Our references to the records an alert came from. Not metadata - that's ActiveStorage's,
    # and analyze merges the whole hash back off its own read
    def stamp(blob, values)
      blob.tap { it.binx_data = it.binx_data.to_h.merge(values) }
    end

    def generate_alert(template:, image:, location_text:, convert: "jpeg")
      config = TEMPLATE_CONFIG[template]
      raise "Unknown template (#{template})!" unless config.present?

      # image_processing 2.0 no longer sharpens after resize; the alerts keep it
      bike_image = ImageProcessing::Vips.source(image)
        .resize_to_limit(*bike_image_dimensions_for(config), sharpen: true)
        .call(save: false)
      # using save: false enables calculating the dimensions & we don't need the intermediary images

      # Put bike image onto the alert template
      alert_image = ImageProcessing::Vips.source(template_path(template))
        .composite(bike_image,
          mode: :over,
          offset: bike_image_offset(config, bike_image.width, bike_image.height)).call(save: false)

      # Add the topbar
      alert_image = ImageProcessing::Vips.source(alert_image)
        .composite(topbar_path(config[:topbar]),
          mode: :over,
          offset: [0, 0])
      return alert_image.convert(convert).call if location_text.blank?

      # Add the location
      location_image = caption_overlay(location_text)
      ImageProcessing::Vips.source(alert_image.call(save: false))
        .composite(location_image,
          mode: :over,
          gravity: "south-east",
          offset: [0, 40]).convert(convert).call
    end

    def template_path(template_sym)
      Rails.root.join(PROMOTED_ALERTS_PATH, "template-#{template_sym}.png").to_s
    end

    def topbar_path(variety)
      filename = (variety == :horizontal) ? "topbar" : "topbar-vertical"
      Rails.root.join(PROMOTED_ALERTS_PATH, "#{filename}.png").to_s
    end

    def bike_image_dimensions_for(config)
      if config[:topbar] == :horizontal
        [config[:dimensions].first,
          config[:dimensions].last - TOPBAR_HORIZONTAL_HEIGHT]
      else
        [config[:dimensions].first - TOPBAR_VERTICAL_WIDTH,
          config[:dimensions].last]
      end
    end

    def bike_image_offset(config, bike_image_width, bike_image_height)
      # for some reason, :centre and offset fails - so get the dimensions and manually center the image
      left_offset = (config[:dimensions].first - bike_image_width) / 2
      top_offset = (config[:dimensions].last - bike_image_height) / 2
      if config[:topbar] === :horizontal
        # opengraph images look better vertically centered in the template. If offset is < top-bar height,
        # the image takes up the whole visible area - so use the top-bar min height. Otherwise, use the
        # offset (which vertically centers the image).
        top_offset = TOPBAR_HORIZONTAL_HEIGHT if top_offset < TOPBAR_HORIZONTAL_HEIGHT
      elsif left_offset < TOPBAR_VERTICAL_WIDTH
        left_offset = TOPBAR_VERTICAL_WIDTH
      end
      # update the left offset

      [left_offset, top_offset]
    end

    # enable passing in DPI because if the caption is too large, it should
    def caption_overlay(text, dpi: 400, border_width: 20)
      # Add the text to the image
      text_overlay = Vips::Image.text(text, font:, dpi:)

      bg_color = [0, 0, 0] # topbar is 26, 26, 26
      text_with_bg = text_overlay.ifthenelse([255, 255, 255], bg_color, blend: true)
      text_with_bg.embed(
        border_width,                           # Left margin
        border_width,                           # Top margin
        text_with_bg.width + 2 * border_width,    # New width (original + left + right margin)
        text_with_bg.height + 1.5 * border_width, # New height (bottom border smaller because comma expands lower coverage)
        background: bg_color          # Border color
      ).copy(interpretation: :srgb)   # Convert to a colorspace that can combine with the other image
    end

    # The font to use in the caption. Set fallbacks since different environments
    # have different fonts available.
    def font
      if fc_list_has?("Helvetica", "Oblique")
        "Helvetica Oblique"
      elsif fc_list_has?("Arial", "Italic")
        "Arial Italic"
      elsif fc_list_has?("Lato", "Italic")
        "Lato Italic"
      elsif fc_list_has?("DejaVu Sans")
        "DejaVu Sans"
      end
    end

    def fc_list_output
      @fc_list_output ||= `fc-list`.to_s
    end

    def fc_list_has?(*terms)
      terms.all? { |term| fc_list_output.match?(/#{Regexp.escape(term)}/i) }
    end

    # The stolen location to be displayed on the promoted alert image
    # Escape single-quotes in the location text
    def stolen_record_location(stolen_record)
      return nil unless stolen_record.to_coordinates.any?

      stolen_record.formatted_address_string(visible_attribute: :city, render_country: :if_different)
        .gsub("'", "\\'")
    end

    conceal :image_and_id, :use_stolen_images_override_id?, :attach_images, :create_alert_blob,
      :stamp, :generate_alert, :template_path, :topbar_path, :bike_image_dimensions_for,
      :bike_image_offset, :caption_overlay, :font, :fc_list_output, :fc_list_has?,
      :stolen_record_location
  end
end
