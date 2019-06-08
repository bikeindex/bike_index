require "rails_helper"

RSpec.describe UnknownOrganizationForAscendImportWorker, type: :job do
  let(:bulk_import) { FactoryBot.create(:bulk_import_ascend) }

  it "sends an email" do
    ActionMailer::Base.deliveries = []
    UnknownOrganizationForAscendImportWorker.new.perform(bulk_import.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
