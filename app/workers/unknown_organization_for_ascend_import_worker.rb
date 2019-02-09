class UnknownOrganizationForAscendImportWorker
  include Sidekiq::Worker
  sidekiq_options queue: "notify"
  sidekiq_options backtrace: true

  def perform(id)
    AdminMailer.unknown_organization_for_ascend_import(BulkImport.find(id)).deliver_now
  end
end
