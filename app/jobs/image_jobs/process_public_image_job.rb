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

      # Written last, once the variants exist - "stripped" only means the original was rewritten
      stamp!(blob, "processed" => true)
    end

    private

    # Direct uploads go browser -> R2, so the original arrives with EXIF intact - including the
    # GPS coordinates of wherever the bike was photographed, which is usually someone's home.
    # Rewrites in place: variant keys derive from blob.key, so reusing it keeps every URL stable.
    # Vips autorotates on load, so orientation survives stripping the tag that encoded it.
    def prepare_image(blob)
      to_webp = PublicImage::WEBP_SOURCE_TYPES.include?(blob.content_type)
      prepared = blob.open do |file|
        source = ImageProcessing::Vips.source(file).saver(strip: true)
        # n: -1 keeps every frame of an animated gif or apng - the default reads page one, so
        # re-encoding silently flattens them. Not for the webp conversions: pages there are a
        # tiff's scans or a heic burst, which shouldn't become an animation.
        to_webp ? source.convert("webp").call : source.loader(n: -1).call
      end
      # Ahead of the upload, which re-identifies content_type with the filename as a hint
      blob.filename = "#{blob.filename.base}.webp" if to_webp
      blob.upload(prepared) # Resets checksum/byte_size, which still describe the pre-strip bytes
      stamp!(blob, "stripped" => true)
    ensure
      prepared&.close!
    end

    # Not metadata: a direct upload posts that (Rails only protects its own keys), so a client
    # could hand us "processed" and skip the strip entirely. Saves the checksum too.
    def stamp!(blob, values)
      blob.update!(binx_data: blob.binx_data.to_h.merge(values))
    end
  end
end
