require "spec_helper"

describe UnknownOrganizationForAscendImportWorker do
  it { is_expected.to be_processed_in :notify }
  let(:bulk_import) { FactoryBot.create(:bulk_import_ascend) }

  it "sends an email" do
    ActionMailer::Base.deliveries = []
    UnknownOrganizationForAscendImportWorker.new.perform(bulk_import.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
