# frozen_string_literal: true

# Images are linked by external sources - so don't purge them in Images::StolenProcessor
# Do it after a delay (and after we've verified the new images are correct)
class StolenBike::RemoveOrphanedImagesJob < ScheduledJob
  prepend ScheduledJobRecorder

  class << self
    def frequency
      30.hours
    end

    def check_period
      1.week.ago..1.day.ago
    end

    def blobs_for(stolen_record_id)
      ActiveStorage::Blob.where("filename ILIKE ?", "stolen-#{stolen_record_id}-%")
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
      delete_alert_images!(stolen_record_id)
      attachments(stolen_record_id).destroy_all
    end
  end

  private

  def delete_all_images!(stolen_record_id)
    delete_alert_images!(stolen_record_id)
    self.class.blobs_for(stolen_record_id).each { |blob| blob.purge }
    # raises undefined method `attachment_reflections' if no attachments
    found_attachments = attachments(stolen_record_id)
    found_attachments.destroy_all if found_attachments.any?
  end

  def delete_alert_images!(stolen_record_id)
    AlertImage.where(stolen_record_id:).destroy_all
  end

  def delete_outdated_blobs!(stolen_record_id)
    self.class.blobs_for(stolen_record_id).where.not(id: attachments(stolen_record_id)
      .pluck(:blob_id))
      .each { |blob| blob.purge }
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
