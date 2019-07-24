class UnknownOrganizationForAscendImportWorker < ApplicationWorker
  sidekiq_options queue: "notify"

  def perform(id)
    AdminMailer.unknown_organization_for_ascend_import(BulkImport.find(id)).deliver_now
  end
end
