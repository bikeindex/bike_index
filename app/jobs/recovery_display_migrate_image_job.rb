class RecoveryDisplayMigrateImageJob < ApplicationJob
  def perform(recovery_display_id)
    recovery_display = RecoveryDisplay.find_by_id(recovery_display_id)
    return unless recovery_display.present?

    # Skip if already migrated to ActiveStorage
    return if recovery_display.photo.attached?

    # Skip if no CarrierWave image
    return unless recovery_display.image.present? && recovery_display.image.file.exists?

    # Download the original image from CarrierWave
    image_file = recovery_display.image.file
    filename = File.basename(image_file.path)

    # Attach to ActiveStorage
    recovery_display.photo.attach(
      io: File.open(image_file.path),
      filename:,
      content_type: image_file.content_type
    )
  end
end
