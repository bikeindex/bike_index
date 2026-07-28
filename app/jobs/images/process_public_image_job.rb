# frozen_string_literal: true

require "image_processing/vips"

module Images
  class ProcessPublicImageJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(public_image_id)
      public_image = PublicImage.unscoped.find_by(id: public_image_id)
      return unless public_image&.file&.attached?

      strip_metadata(public_image.file.blob) if public_image.file_needs_processing?
      # Variants aren't declared `preprocessed` - they'd generate off the un-stripped original
      # on the attachment's own after_commit, racing the strip above.
      PublicImage::VARIANTS.each_key { |size| public_image.file.variant(size).processed }
    end

    private

    # Direct uploads go browser -> R2, so the original arrives with EXIF intact - including the
    # GPS coordinates of wherever the bike was photographed, which is usually someone's home.
    # Rewrites in place: variant keys derive from blob.key, so reusing it keeps every URL stable.
    # Vips autorotates on load, so orientation survives stripping the tag that encoded it.
    def strip_metadata(blob)
      stripped = blob.open { |file| ImageProcessing::Vips.source(file).saver(strip: true).call }
      blob.upload(stripped) # Resets checksum/byte_size, which still describe the pre-strip bytes
      blob.update!(metadata: blob.metadata.merge("stripped" => true))
      blob.analyze # PublicImage suppresses AnalyzeJob, so this is metadata's only writer
    ensure
      stripped&.close!
    end
  end
end
