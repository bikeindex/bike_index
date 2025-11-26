class Backfills::RecoveryDisplayMigrateImageJob < ApplicationJob
  def perform(recovery_display_id)
    recovery_display = RecoveryDisplay.find_by_id(recovery_display_id)
    return unless recovery_display.present?

    # Skip if already migrated to ActiveStorage, or if no image
    return if recovery_display.photo.attached? || recovery_display.image.blank?

    Images::ProcessRecoveryDisplayPhotoJob.new.perform(
      recovery_display_id, recovery_display.image.path, recovery_display:
    )

    # # Download the original image from CarrierWave
    # image_file = recovery_display.image.file
    # filename = File.basename(image_file.path)

    # # Attach to ActiveStorage
    # recovery_display.photo.attach(
    #   io: File.open(image_file.path),
    #   filename:,
    #   content_type: image_file.content_type
    # )
  end
end
