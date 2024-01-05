require "rails_helper"

RSpec.describe InvalidExtensionForAscendImportWorker, type: :job do
  let(:instance) { described_class.new }
  let(:organization) { FactoryBot.create(:organization) }
  let!(:bulk_import) { FactoryBot.create(:bulk_import_ascend, organization: organization) }

  it "creates an organization_status, notification and sends an email" do
    ActionMailer::Base.deliveries = []
    expect(OrganizationStatus.count).to eq 0
    expect(Notification.count).to eq 0
    instance.perform(bulk_import.id)
    instance.perform(bulk_import.id)
    expect(OrganizationStatus.count).to eq 1
    expect(Notification.count).to eq 1
    expect(ActionMailer::Base.deliveries.count).to eq 1

    notification = Notification.last
    expect(notification.kind).to eq "organization_pos_integration_broken"
  end
end
