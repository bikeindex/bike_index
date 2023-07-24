class UnknownOrganizationForAscendImportWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  # enable temporarily skipping the email, because we have a bunch of errored
  SKIP_UNKNOWN_ASCEND_EMAIL = ENV["SKIP_UNKNOWN_ASCEND_EMAIL"].present?

  def perform(id)
    return if SKIP_UNKNOWN_ASCEND_EMAIL
    AdminMailer.unknown_organization_for_ascend_import(BulkImport.find(id)).deliver_now
  end
end
