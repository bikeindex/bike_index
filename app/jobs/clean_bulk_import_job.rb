class CleanBulkImportJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    25.hours
  end

  def self.clean_before
    Time.current - 48.hours
  end

  def perform(import_id = nil)
    return enqueue_workers unless import_id.present?
    bulk_import = BulkImport.find(import_id)
    return true if bulk_import.file_cleaned
    bulk_import.file_cleaned = true
    bulk_import.file&.remove!
    bulk_import.save
  end

  def enqueue_workers
    BulkImport.ascend.where(file_cleaned: false).where("created_at < ?", self.class.clean_before)
      .limit(1_000)
      .pluck(:id).each { |id| self.class.perform_async(id) }
  end
end
