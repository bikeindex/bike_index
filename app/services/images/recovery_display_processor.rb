# frozen_string_literal: true

require "image_processing/vips"

class Images::RecoveryDisplayProcessor
  DIMENSIONS = [800, 800].freeze

  class << self
    def process_photo(recovery_display, force_regenerate: false)
      return unless recovery_display.photo.attached?
      return if !force_regenerate && recovery_display.photo_processed.attached?

      processed_blob = ActiveStorage::Blob.create_and_upload!(
        io: generate_square_image(recovery_display.photo),
        filename: "recovery-#{recovery_display.id}.jpeg"
      )
      processed_blob.analyze

      recovery_display.photo_processed.attach(processed_blob)
      recovery_display
    end

    private

    def generate_square_image(photo)
      photo.blob.open do |file|
        ImageProcessing::Vips.source(file)
          .resize_to_fill(*DIMENSIONS)
          .convert("jpeg")
          .call
      end
    end
  end
end
