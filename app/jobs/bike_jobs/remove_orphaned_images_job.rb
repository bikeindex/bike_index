# frozen_string_literal: true

# Images are linked by external sources - so don't purge them in ImageServices::StolenProcessor
# Do it after a delay (and after we've verified the new images are correct)
module BikeJobs
  class RemoveOrphanedImagesJob < ScheduledJob
    prepend ScheduledJobRecorder

    # Purging hits S3, which returns transient 5xx. Without a retry every blip opens a
    # Honeybadger fault, since the attempt_threshold only applies to retryable jobs
    sidekiq_options retry: 1

    class << self
      def frequency
        30.hours
      end

      def check_period
        1.week.ago..1.day.ago
      end

      # The stamp rather than the filename - this purges what it matches, and a user can name
      # an upload "stolen-42-whatever.jpg"
      def blobs_for(stolen_record_id)
        ActiveStorage::Blob.where("binx_data->>'stolen_record_id' = ?", stolen_record_id.to_s)
          .where("created_at < ?", check_period.last)
      end
    end

    def perform(stolen_record_id = nil)
      return enqueue_workers unless stolen_record_id.present?

      stolen_record = StolenRecord.find_by(id: stolen_record_id)

      if stolen_record.present?
        if stolen_record.images_attached?
          delete_alert_images!(stolen_record_id)
          delete_outdated_blobs!(stolen_record_id)
        elsif stolen_record.bike_main_image.blank?
          delete_all_images!(stolen_record_id)
        end
      else
        delete_all_images!(stolen_record_id)
      end
    end

    private

    def delete_all_images!(stolen_record_id)
      delete_alert_images!(stolen_record_id)
      # Attachments first - purge_blob skips a blob that still has one. delete_all skips
      # after_commit callbacks that crash when the record is gone
      attachments(stolen_record_id).delete_all
      self.class.blobs_for(stolen_record_id).each { |blob| purge_blob(blob) }
    end

    def delete_alert_images!(stolen_record_id)
      AlertImage.where(stolen_record_id:).destroy_all
    end

    def delete_outdated_blobs!(stolen_record_id)
      self.class.blobs_for(stolen_record_id).where.not(id: attachments(stolen_record_id)
        .pluck(:blob_id))
        .each { |blob| purge_blob(blob) }
    end

    # ActiveStorage's purge destroys the row and then deletes the file, so a transient S3
    # failure orphans the file forever. Deleting first leaves the row for the next run to
    # retry; the exists? check stands in for the guard purge gets from destroying first
    def purge_blob(blob)
      return if blob.attachments.exists?

      blob.delete
      blob.destroy!
    end

    def attachments(record_id)
      ActiveStorage::Attachment.where(record_type: "StolenRecord", record_id:)
    end

    def enqueue_workers
      Bike.unscoped.joins(:stolen_records)
        .where(deleted_at: self.class.check_period)
        .pluck("stolen_records.id")
        .each { |id| self.class.perform_async(id) }

      ActiveStorage::Attachment.where(record_type: "StolenRecord")
        .where(created_at: self.class.check_period).distinct.pluck(:record_id)
        .each { |id| self.class.perform_async(id) }

      # Enqueue these *after* active storage attachment, there might be some overlap with deleted
      StolenRecord.unscoped.where(recovered_at: self.class.check_period).pluck(:id)
        .each { |id| self.class.perform_async(id) }
    end
  end
end
