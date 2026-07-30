# frozen_string_literal: true

require "image_processing/vips"

module ImageJobs
  class ProcessPublicImageJob < ApplicationJob
    sidekiq_options queue: "med_priority"

    def perform(public_image_id)
      public_image = PublicImage.unscoped.find_by(id: public_image_id)
      return unless public_image&.file_needs_processing?

      blob = public_image.file.blob
      prepare_image(blob) unless blob.binx_data.to_h["stripped"] # A second pass would re-encode
      # Not `preprocessed` - those generate off the un-stripped original, racing the strip
      PublicImage::VARIANTS.each_key { |size| public_image.file.variant(size).processed }

      stamp!(blob, "processed" => true) # Last, so it means every variant exists
    end

    private

    # Uploads reach R2 without passing through Rails, so the original still carries the GPS
    # coordinates of wherever the bike was photographed. Reuses blob.key to keep URLs stable;
    # vips autorotates on load, so orientation survives losing the tag that encoded it.
    def prepare_image(blob)
      to_webp = PublicImage::WEBP_SOURCE_TYPES.include?(blob.content_type)
      prepared = blob.open do |file|
        source = ImageProcessing::Vips.source(file).saver(strip: true)
        # n: -1 keeps every gif frame; vips reads page one otherwise. Not when converting -
        # pages there are a tiff's scans, which shouldn't become an animation
        to_webp ? source.convert("webp").call : source.loader(n: -1).call
      end
      # Before the upload, which re-identifies content_type using the filename
      blob.filename = "#{blob.filename.base}.webp" if to_webp
      blob.upload(prepared) # Resets checksum/byte_size, which still describe the pre-strip bytes
      stamp!(blob, "stripped" => true)
    ensure
      prepared&.close!
    end

    # Not metadata - a direct upload posts that, so a client could claim to be processed
    def stamp!(blob, values)
      blob.update!(binx_data: blob.binx_data.to_h.merge(values))
    end
  end
end
