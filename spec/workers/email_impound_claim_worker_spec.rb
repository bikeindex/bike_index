require "rails_helper"

RSpec.describe EmailImpoundClaimWorker, type: :job do
  let!(:impound_claim) { FactoryBot.create(:impound_claim, status: status) }
  let(:status) { "pending" }
  before { ActionMailer::Base.deliveries = [] }

  it "doesn't send an email for pending claims" do
    expect {
      EmailImpoundClaimWorker.new.perform(impound_claim.id)
    }.to change(Notification, :count).by(0)
    expect(ActionMailer::Base.deliveries.count).to eq 0
  end

  context "submitted" do
    let(:status) { "submitting" }
    it "sends just once" do
      expect {
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
      }.to change(Notification, :count).by(1)
      notification = Notification.last
      expect(impound_claim.reload.notifications.pluck(:id)).to eq([notification.id])
      expect(notification.kind).to eq "impound_claim_submitting"
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end

  context "approved" do
    let(:status) { "approved" }
    it "sends just once" do
      expect {
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
      }.to change(Notification, :count).by(1)
      notification = Notification.last
      expect(impound_claim.reload.notifications.pluck(:id)).to eq([notification.id])
      expect(notification.kind).to eq "impound_claim_approved"
      expect(notification.delivery_status).to eq "email_success"
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end

  context "denied" do
    let(:status) { "denied" }
    it "sends just once" do
      expect {
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
        EmailImpoundClaimWorker.new.perform(impound_claim.id)
      }.to change(Notification, :count).by(1)
      notification = Notification.last
      expect(impound_claim.reload.notifications.pluck(:id)).to eq([notification.id])
      expect(notification.kind).to eq "impound_claim_denied"
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end
end
