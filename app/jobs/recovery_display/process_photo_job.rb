class RecoveryDisplay::ProcessPhotoJob < ApplicationJob
  sidekiq_options retry: false

  def perform(recovery_display_id, remote_photo_url = nil, force_regenerate = false)
    recovery_display = RecoveryDisplay.find_by_id(recovery_display_id)
    return unless recovery_display.present?

    # If remote_photo_url is provided, download and attach it
    if remote_photo_url.present? && !recovery_display.photo.attached?
      downloaded_image = URI.parse(remote_photo_url).open
      filename = File.basename(URI.parse(remote_photo_url).path)
      recovery_display.photo.attach(io: downloaded_image, filename:)
    end

    # Process the photo to create photo_processed
    Images::RecoveryDisplayProcessor.process_photo(recovery_display, force_regenerate:)
  end
end
