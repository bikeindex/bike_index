class RecoveryDisplay::AfterPhotoAttachJob < ApplicationJob
  sidekiq_options retry: false

  def perform(recovery_display_id, force_regenerate: false)
    recovery_display = RecoveryDisplay.find_by_id(recovery_display_id)
    return unless recovery_display.present?

    Images::RecoveryDisplayProcessor.process_photo(recovery_display, force_regenerate:)
  end
end
