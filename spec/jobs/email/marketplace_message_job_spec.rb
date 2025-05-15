require "rails_helper"

RSpec.describe Email::MarketplaceMessageJob, type: :job do
  let!(:marketplace_message) { FactoryBot.create(:marketplace_message) }

  let(:target_notification_attrs) do
    {
      kind: "marketplace_message",
      delivery_status: "delivery_success",
      notifiable: marketplace_message,
      user_id: marketplace_message.receiver_id
    }
  end
  it "sends an email" do
    ActionMailer::Base.deliveries = []
    expect(Notification.count).to eq 0
    expect {
      described_class.new.perform(marketplace_message.id)
    }.to change(described_class.jobs, :count).by 0
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    expect(Notification.count).to eq 1
    expect(Notification.last).to have_attributes target_notification_attrs
  end
  context "donation, existing notification" do
    let!(:notification) do
      Notification.create(notifiable: marketplace_message, kind: "marketplace_message", delivery_status: "delivery_success")
    end
    it "does not send an email" do
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 1
      expect {
        described_class.new.perform(marketplace_message.id)
      }.to change(described_class.jobs, :count).by 0
      expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      expect(Notification.count).to eq 1
    end
  end
end
