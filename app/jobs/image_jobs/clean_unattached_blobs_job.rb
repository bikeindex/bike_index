# frozen_string_literal: true

module ImageJobs
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

    # Superseded alert images are unattached on purpose (dependent: false, so links to one keep
    # resolving) and BikeJobs::RemoveOrphanedImagesJob collects them within a week. This sweeps
    # what it misses - exempting them instead would turn a missed collection into a leak
    def blobs
      ActiveStorage::Blob.unattached.where(created_at: ...self.class.clean_before).limit(BATCH_SIZE)
    end
  end
end
