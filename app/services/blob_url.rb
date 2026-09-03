# frozen_string_literal: true

# Direct route for active storage, lipanski.com/posts/activestorage-cdn-rails-direct-route
module BlobUrl
  extend Functionable

  SERVICE = Bikeindex::Application.config.active_storage.service
  LOCAL_STORAGE = %i[local test].include?(SERVICE)
  STORAGE_HOST = ENV.fetch("ACTIVE_STORAGE_HOST", "https://uploads.bikeindex.org")
  # Each non-production bucket has its own domain; an unlisted service serves from production's
  STORAGE_HOSTS = {
    cloudflare_dev: ENV.fetch("ACTIVE_STORAGE_HOST_DEV", "https://dev-uploads.bikeindex.org"),
    cloudflare_test: ENV.fetch("ACTIVE_STORAGE_HOST_TEST", "https://test-uploads.bikeindex.org")
  }.freeze

  def for(blob = nil)
    return if blob.blank?
    # Preserve the behavior of `rails_blob_url` when using file storage
    if local_storage?(blob)
      Rails.application.routes.url_helpers.rails_blob_url(blob)
    else
      File.join(storage_host_for(blob), blob.key || "") # Use the CDN
    end
  end

  # `size` is a named variant. Never calls `processed` - that would be a storage existence
  # check per image per render, and the post-attach job guarantees they exist
  def for_variant(attached = nil, size = nil)
    return if attached.blank?
    return self.for(attached.blob) if size.blank?

    variant = attached.variant(size)
    if local_storage?(attached.blob)
      Rails.application.routes.url_helpers.rails_representation_url(variant)
    else
      File.join(storage_host_for(attached.blob), variant.key) # Deterministic, no query
    end
  end

  #
  # private below here
  #

  def local_storage?(blob)
    LOCAL_STORAGE && blob.service&.name == SERVICE
  end

  def storage_host_for(blob)
    STORAGE_HOSTS[blob.service&.name] || STORAGE_HOST
  end

  conceal :local_storage?, :storage_host_for
end
