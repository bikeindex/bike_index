# frozen_string_literal: true

# Images are linked by external sources - so don't purge them in Images::StolenProcessor
# Do it after a delay (and after we've verified the new images are correct)
class StolenBike::RemoveOrphanedImagesJob < ScheduledJob
  prepend ScheduledJobRecorder

  def perform(stolen_record_id = nil)

    # stolen_record.alert_image&.destroy
    # stolen_record.image_four_by_five.purge
    # stolen_record.image_square.purge
    # stolen_record.image_landscape.purge
  end
end
