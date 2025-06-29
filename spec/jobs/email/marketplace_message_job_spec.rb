require "rails_helper"

RSpec.describe Email::MarketplaceMessageJob, type: :job do
  let!(:marketplace_message) { FactoryBot.create(:marketplace_message) }

  let(:target_notification_attrs) do
    {
      kind: "marketplace_message",
      delivery_status: "delivery_success",
      notifiable: marketplace_message,
      user_id: marketplace_message.receiver_id,
      message_id: be_present,
      bike_id: marketplace_message.marketplace_listing.item_id
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
    notification = Notification.last
    expect(notification).to have_attributes target_notification_attrs
  end
  context "reply to" do
    let(:marketplace_message_reply) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message) }
    it "uses the reference id" do
      ActionMailer::Base.deliveries = []
      expect(Notification.count).to eq 0
      expect {
        described_class.new.perform(marketplace_message.id)
      }.to change(described_class.jobs, :count).by(0).and change(Notification, :count).by(1)
      expect(marketplace_message.reload.email_references_id).to be_nil
      notification = Notification.order(:id).last
      expect(notification.message_id).to be_present

      expect(marketplace_message_reply.reload.email_references_id).to eq "<#{notification.message_id}>"
      result = described_class.new.perform(marketplace_message_reply.id)
      expect(ActionMailer::Base.deliveries.count).to eq 2
      expect(Notification.count).to eq 2
      expect(Notification.order(:id).last.message_id).to be_present
      expect(result.references).to eq notification.message_id
      # sanity check - still choosing the first message id
      expect(marketplace_message_reply.reload.email_references_id).to eq "<#{notification.message_id}>"
    end
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
      expect(notification.reload.message_id).to be_blank
    end
  end
end
