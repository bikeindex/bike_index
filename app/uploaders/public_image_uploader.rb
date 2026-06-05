# PublicImage uploads run synchronously inside the web request, so caching to
# S3 (the default when storage = :fog) adds a wasteful PUT + DELETE round-trip
# that can push large requests past the 30s Rack::Timeout. Cache locally and
# only hit S3 for the final store + versions.
class PublicImageUploader < ImageUploader
  # Reject oversized uploads before any processing/storage. Shared with
  # PublicImagesController, which rejects on Content-Length before caching.
  MAX_FILE_SIZE = 16.megabytes

  cache_storage :file

  def size_range
    0..MAX_FILE_SIZE
  end
end
