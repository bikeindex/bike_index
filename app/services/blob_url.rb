# frozen_string_literal: true

# Direct route for active storage, lipanski.com/posts/activestorage-cdn-rails-direct-route
class BlobUrl
  SERVICE = Bikeindex::Application.config.active_storage.service
  LOCAL_STORAGE = %i[local test].include?(SERVICE)
  STORAGE_HOST = ENV.fetch("ACTIVE_STORAGE_HOST", "https://uploads.bikeindex.org")
  STORAGE_HOST_DEV = ENV.fetch("ACTIVE_STORAGE_HOST_DEV", nil)

  class << self
    def for(blob = nil)
      return if blob.blank?
      # Preserve the behavior of `rails_blob_url` when using file storage
      if local_storage?(blob)
        Rails.application.routes.url_helpers.rails_blob_url(blob)
      else
        File.join(storage_host_for(blob), blob.key || "") # Use the CDN
      end
    end

    private

    def local_storage?(blob)
      LOCAL_STORAGE && blob.service&.name == SERVICE
    end

    def storage_host_for(blob)
      return STORAGE_HOST if STORAGE_HOST_DEV.blank? || blob.service&.name != :cloudflare_dev

      STORAGE_HOST_DEV
    end
  end
end
