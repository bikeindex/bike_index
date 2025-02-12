require "rails_helper"

RSpec.describe UnknownOrganizationForAscendImportWorker, type: :job do
  let!(:bulk_import) { FactoryBot.create(:bulk_import_ascend) }
  let(:instance) { described_class.new }

  it "sends an email" do
    expect(Notification.count).to eq 0
    ActionMailer::Base.deliveries = []
    instance.perform(bulk_import.id)
    instance.perform(bulk_import.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq(["gavin@bikeindex.org", "craig@bikeindex.org"])
    expect(mail.subject).to match("Unknown organization for ascend import")
    expect(mail.tag).to eq("admin")

    expect(Notification.count).to eq 1
    notification = Notification.last
    expect(notification.kind).to eq "unknown_organization_for_ascend"
    expect(notification.delivery_success?).to be_truthy
    expect(notification.notifiable).to eq bulk_import
  end
end
