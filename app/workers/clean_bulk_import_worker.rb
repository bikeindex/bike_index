class CleanBulkImportWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.hours
  end

  def self.clean_before
    Time.current - 48.hours
  end

  def perform(import_id = nil)
    return enqueue_workers unless import_id.present?
    bulk_import = BulkImport.find(import_id)
    bulk_import.file_cleaned = true
    bulk_import.file&.remove!
    bulk_import.save
  end

  def enqueue_workers
    BulkImport.ascend.where("created_at < ?", self.class.clean_before)
      .pluck(:id).each { |id| self.class.perform_async(id) }
  end
end
