# frozen_string_literal: true

require "image_processing/vips"

module Images
  class ProcessPublicImageJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    # No browser renders TIFF and only Safari renders HEIC, and the original is served directly
    WEBP_SOURCE_TYPES = %w[image/heic image/heif image/tiff].freeze

    def perform(public_image_id)
      public_image = PublicImage.unscoped.find_by(id: public_image_id)
      return unless public_image&.file&.attached?

      blob = public_image.file.blob
      # Guarded on "stripped" rather than file_needs_processing? - preparing twice would re-encode
      # the original, so a retry after a partial run must not repeat it
      prepare_image(blob) unless blob.metadata["stripped"]
      # Variants aren't declared `preprocessed` - they'd generate off the un-stripped original
      # on the attachment's own after_commit, racing the strip above.
      PublicImage::VARIANTS.each_key { |size| public_image.file.variant(size).processed }

      # Written last. "stripped" lands halfway through, so it answers "was the original rewritten?",
      # not "is this image ready?" - only this says every variant exists too.
      blob.update!(metadata: blob.metadata.merge("processed" => true))
    end

    private

    # Direct uploads go browser -> R2, so the original arrives with EXIF intact - including the
    # GPS coordinates of wherever the bike was photographed, which is usually someone's home.
    # Rewrites in place: variant keys derive from blob.key, so reusing it keeps every URL stable.
    # Vips autorotates on load, so orientation survives stripping the tag that encoded it.
    def prepare_image(blob)
      to_webp = WEBP_SOURCE_TYPES.include?(blob.content_type)
      prepared = blob.open do |file|
        source = ImageProcessing::Vips.source(file).saver(strip: true)
        (to_webp ? source.convert("webp") : source).call
      end
      # Ahead of the upload, which re-identifies content_type with the filename as a hint
      blob.filename = "#{blob.filename.base}.webp" if to_webp
      blob.upload(prepared) # Resets checksum/byte_size, which still describe the pre-strip bytes
      blob.update!(metadata: blob.metadata.merge("stripped" => true))
      blob.analyze # PublicImage suppresses AnalyzeJob, so this is metadata's only writer
    ensure
      prepared&.close!
    end
  end
end
