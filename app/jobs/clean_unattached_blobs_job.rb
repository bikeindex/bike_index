# frozen_string_literal: true

# A blob is uploaded before the record that references it is saved, so a form the user
# abandons after picking a file leaves a blob nothing will ever attach.
class CleanUnattachedBlobsJob < ScheduledJob
  prepend ScheduledJobRecorder

  BATCH_SIZE = 1000 # Bounds a run; the rest keeps until tomorrow

  def self.frequency
    25.hours
  end

  # Nothing here is urgent, and a blob can legitimately wait on a confirmation email
  def self.clean_before
    Time.current - 30.days
  end

  def perform
    blobs.each { it.purge_later }
  end

  # Alert images are unattached on purpose - StolenRecord attaches them with dependent: false
  # so links to a superseded one keep resolving. BikeJobs::RemoveOrphanedImagesJob owns those
  # and knows when they're safe to drop. The filename match covers whatever
  # Backfills::StolenAlertBlobBinxDataJob hasn't stamped, and can go once it has run.
  def blobs
    ActiveStorage::Blob.unattached.where(created_at: ...self.class.clean_before)
      .where("binx_data->>'stolen_record_id' IS NULL")
      .where.not("filename ILIKE ?", "stolen-%").limit(BATCH_SIZE)
  end
end
