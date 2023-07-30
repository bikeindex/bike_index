class InvalidExtensionForAscendImportWorker < ApplicationWorker
  sidekiq_options queue: "notify"
  SKIP_ASCEND_EMAIL = ENV["SKIP_UNKNOWN_ASCEND_EMAIL"].present?

  def perform(id)
    return if SKIP_ASCEND_EMAIL
    AdminMailer.invalid_extension_for_ascend_import(BulkImport.find(id)).deliver_now
  end
end
