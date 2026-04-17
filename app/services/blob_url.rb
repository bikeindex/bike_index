# frozen_string_literal: true

# Direct route for active storage, lipanski.com/posts/activestorage-cdn-rails-direct-route
module BlobUrl
  extend Functionable

  STORAGE_HOST = ENV.fetch("ACTIVE_STORAGE_HOST", "https://uploads.bikeindex.org")
  STORAGE_HOST_DEV = ENV.fetch("ACTIVE_STORAGE_HOST_DEV", nil)

  def for(blob = nil)
    return if blob.blank?
    # Preserve the behavior of `rails_blob_url` when using file storage
    if local_storage?(blob)
      Rails.application.routes.url_helpers.rails_blob_url(blob)
    else
      File.join(storage_host_for(blob), blob.key || "") # Use the CDN
    end
  end

  #
  # private below here
  #

  def local_storage?(blob)
    %i[local test].include?(blob.service&.name)
  end

  def storage_host_for(blob)
    return STORAGE_HOST if STORAGE_HOST_DEV.blank? || blob.service&.name != :cloudflare_dev

    STORAGE_HOST_DEV
  end

  conceal :local_storage?, :storage_host_for
end
