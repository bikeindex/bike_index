require "rails_helper"

RSpec.describe InvalidExtensionForAscendImportWorker, type: :job do
  let(:instance) { described_class.new }
  let(:organization) { FactoryBot.create(:organization, ascend_name: "Something") }
  let(:user) { FactoryBot.create(:user) }
  let(:bulk_import) { FactoryBot.create(:bulk_import_ascend, organization: organization) }
  before do
    # Stub so bulk_import has invalid_extension
    stub_const("BulkImport::VALID_FILE_EXTENSIONS", [])
    bulk_import.save
    # Stub so notification is sent to correct user
    stub_const("InvalidExtensionForAscendImportWorker::NOTIFICATION_USER_ID", user.id)
  end

  it "creates an organization_status, notification and sends an email" do
    expect(bulk_import.blocking_error?).to be_truthy
    expect(bulk_import.file_errors.to_s).to match(/Invalid file extension/i)
    ActionMailer::Base.deliveries = []
    expect(OrganizationStatus.count).to eq 0
    expect(Notification.count).to eq 0
    instance.perform(bulk_import.id)
    instance.perform(bulk_import.id) # Do it again to verify it only notifies once
    expect(OrganizationStatus.count).to eq 2
    expect(OrganizationStatus.pluck(:pos_kind)).to match_array(%w[no_pos broken_ascend_pos])
    organization_status = OrganizationStatus.current.last
    expect(organization_status.organization_id).to eq organization.id
    expect(organization_status.pos_kind).to eq "broken_ascend_pos"
    expect(organization_status.bulk_imports.pluck(:id)).to eq([bulk_import.id])

    expect(Notification.count).to eq 1
    notification = organization_status.notification

    expect(notification.kind).to eq "invalid_extension_for_ascend_import"
    expect(notification.user_id).to eq user.id
    expect(notification.delivery_success?).to be_truthy

    expect(ActionMailer::Base.deliveries.count).to eq 1
  end

  context "unknown organization" do
    let(:bulk_import) { FactoryBot.create(:bulk_import_ascend, organization: nil) }
    it "doesn't notify" do
      expect(bulk_import.blocking_error?).to be_truthy
      expect(bulk_import.file_errors.to_s).to match(/Invalid file extension/i)
      ActionMailer::Base.deliveries = []
      expect(OrganizationStatus.count).to eq 0
      expect(Notification.count).to eq 0
      instance.perform(bulk_import.id)
      instance.perform(bulk_import.id) # Do it again to verify it never notifies
      expect(OrganizationStatus.count).to eq 0
      expect(Notification.count).to eq 0
    end
  end
end
