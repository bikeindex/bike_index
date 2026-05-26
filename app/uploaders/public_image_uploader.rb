# PublicImage uploads run synchronously inside the web request, so caching to
# S3 (the default when storage = :fog) adds a wasteful PUT + DELETE round-trip
# that can push large requests past the 30s Rack::Timeout. Cache locally and
# only hit S3 for the final store + versions.
class PublicImageUploader < ImageUploader
  cache_storage :file
end
