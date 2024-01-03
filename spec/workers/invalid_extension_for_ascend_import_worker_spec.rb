require "rails_helper"

RSpec.describe InvalidExtensionForAscendImportWorker, type: :job do
  let(:bulk_import) { FactoryBot.create(:bulk_import_ascend) }

  it "sends an email" do
    ActionMailer::Base.deliveries = []
    expect(Notification.count).to eq 0
    InvalidExtensionForAscendImportWorker.new.perform(bulk_import.id)
    InvalidExtensionForAscendImportWorker.new.perform(bulk_import.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
    expect(Notification.count).to eq 1
    notification = Notification.last
    expect(notification.kind).to eq organization_pos_integration_broken
  end
end
