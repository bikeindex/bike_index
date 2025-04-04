# frozen_string_literal: true

# Direct route for active storage, lipanski.com/posts/activestorage-cdn-rails-direct-route
class BlobUrl
  SERVICE = Bikeindex::Application.config.active_storage.service
  LOCAL_STORAGE = %i[local test].include?(SERVICE)
  STORAGE_HOST = ENV.fetch("ACTIVE_STORAGE_HOST", "https://uploads.bikeindex.org")

  class << self
    def for(blob = nil)
      return if blob.blank?
      # Preserve the behavior of `rails_blob_url` when using file storage
      if LOCAL_STORAGE && blob.service&.name == SERVICE
        Rails.application.routes.url_helpers.rails_blob_url(blob)
      else
        File.join(STORAGE_HOST, blob.key || "") # Use the CDN
      end
    end
  end
end
