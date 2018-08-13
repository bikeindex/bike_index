require "spec_helper"

describe EmailOrganizationMessageWorker do
  let(:subject) { EmailOrganizationMessageWorker }
  let(:instance) { subject.new }
  it { is_expected.to be_processed_in :notify }

  context "delivery failed" do
    let(:organization_message) { FactoryGirl.create(:organization_message, delivery_status: "failure") }
    it "does not send" do
      ActionMailer::Base.deliveries = []
      instance.perform(organization_message.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end
  context "delivery succeeded" do
    let(:organization_message) { FactoryGirl.create(:organization_message, delivery_status: "success") }
    it "does not send" do
      ActionMailer::Base.deliveries = []
      instance.perform(organization_message.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
    end
  end
  context "delivery_status nil" do
    let(:organization_message) { FactoryGirl.create(:organization_message, delivery_status: nil) }
    it "sends an email" do
      ActionMailer::Base.deliveries = []
      instance.perform(organization_message.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      organization_message.reload
      expect(organization_message.delivery_status).to be_present
    end
  end
end
