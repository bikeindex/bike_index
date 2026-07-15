# Version generation is deferred to a background job (PublicImage's
# `process_in_background :image`) so large uploads don't block the web request
# past the 30s Rack::Timeout. The original is still stored synchronously; the
# job recreates versions by reading that stored original back from S3, so the
# worker never depends on this box's local cache.
#
# Caching to S3 (the default when storage = :fog) would add a wasteful PUT +
# DELETE round-trip on the way in, so cache locally and only hit S3 for the
# original store (and later the backgrounded versions).
class PublicImageUploader < ImageUploader
  include ::CarrierWave::Backgrounder::Delay

  # Reject oversized uploads before any processing/storage. Shared with
  # PublicImagesController, which rejects on Content-Length before caching.
  MAX_FILE_SIZE = 16.megabytes

  cache_storage :file

  def size_range
    0..MAX_FILE_SIZE
  end
end
