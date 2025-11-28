class Backfills::RecoveryDisplayMigrateImageJob < ApplicationJob
  def self.to_migrate
    RecoveryDisplay.where.not(image: nil).where.missing(:photo_attachment)
  end

  def self.enqueue
    to_migrate.pluck(:id).each { self.perform_async(it) }
  end

  def perform(recovery_display_id, force_regenerate = false)
    recovery_display = RecoveryDisplay.find_by_id(recovery_display_id)
    return if recovery_display.blank? || skip_regeneration?(recovery_display, force_regenerate)

    Images::ProcessRecoveryDisplayPhotoJob.new.perform(
      recovery_display_id, recovery_display.image_url, recovery_display:
    )
  end

  private

  def skip_regeneration?(recovery_display, force_regenerate)
    return false if force_regenerate

    # Skip if already migrated to ActiveStorage, or if no image
    recovery_display.photo.attached? || recovery_display.image.blank?
  end
end
