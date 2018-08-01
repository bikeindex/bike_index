require "spec_helper"

describe EmailOrganizationMessageWorker do
  it { is_expected.to be_processed_in :notify }

  context "delivery failed" do
    it "does not send"
  end
  context "delivery succeeded" do
    it "does not send"
  end
  context "delivery_status nil" do
    it "sends an email"
  end
end
