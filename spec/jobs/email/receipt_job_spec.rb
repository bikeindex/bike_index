require "rails_helper"

RSpec.describe Email::ReceiptJob, type: :job do
  let(:payment) { FactoryBot.create(:payment, kind: "payment") }
  it "sends an email" do
    expect(payment.notifications.count).to eq 0
    expect(payment.kind).to eq "payment"
    ActionMailer::Base.deliveries = []
    expect {
      Email::ReceiptJob.new.perform(payment.id)
    }.to change(Email::DonationJob.jobs, :count).by 0
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
    payment.reload
    expect(payment.notifications.count).to eq 1
    notification = payment.notifications.first
    expect(notification.kind).to eq "receipt"
    expect(notification.user_id).to eq payment.user_id
    expect(notification.message_channel).to eq "email"
    expect(notification.notifiable).to eq payment
    expect(notification.delivery_success?).to be_truthy
    expect(notification.message_channel_target).to eq payment.email
  end
  context "donation, existing notification" do
    let(:payment) { FactoryBot.create(:payment, kind: "donation") }
    let!(:notification) { Notification.create(notifiable: payment, kind: "receipt") }
    it "enqueues Email::DonationJob" do
      expect(payment.notifications.count).to eq 1
      expect(payment.kind).to eq "donation"
      expect(notification.delivery_success?).to be_falsey
      ActionMailer::Base.deliveries = []
      expect {
        Email::ReceiptJob.new.perform(payment.id)
      }.to change(Email::DonationJob.jobs, :count).by 1
      expect(ActionMailer::Base.deliveries.count).to eq 1
      payment.reload
      expect(payment.notifications.count).to eq 1
      notification.reload
      expect(notification.kind).to eq "receipt"
      expect(notification.user_id).to eq payment.user_id
      expect(notification.message_channel).to eq "email"
      expect(notification.delivery_success?).to be_truthy
      # Ensure that it actually would send
      Email::DonationJob.drain
      expect(ActionMailer::Base.deliveries.count).to eq 2
      expect(payment.notifications.count).to eq 2
    end
    context "notification delivered" do
      let!(:notification) { Notification.create(notifiable: payment, kind: "receipt", delivery_status: "delivery_success") }
      it "does not email" do
        Email::DonationJob.new.perform(payment.id)
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(payment.reload.notifications.count).to eq 2
        ActionMailer::Base.deliveries = []

        Email::ReceiptJob.new.perform(payment.id)
        Email::DonationJob.drain
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
        expect(payment.reload.notifications.count).to eq 2
      end
    end
  end
end
