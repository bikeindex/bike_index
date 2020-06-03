require "rails_helper"

RSpec.describe EmailOwnershipInvitationWorker, type: :job do
  it "sends an email" do
    ownership = FactoryBot.create(:ownership)
    ActionMailer::Base.deliveries = []
    EmailOwnershipInvitationWorker.new.perform(ownership.id)
    expect(ActionMailer::Base.deliveries).not_to be_empty
  end

  context "ownership does not exist" do
    it "does not send an email" do
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(129291912)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
  context "ownership is for an example bike" do
    let(:bike) { FactoryBot.create(:bike, example: true) }
    let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
    it "does not send, updates ownership to be send_email false" do
      ownership.reload
      expect(ownership.send_email).to be_truthy
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
      expect(ActionMailer::Base.deliveries).to be_empty
      ownership.reload
      expect(ownership.send_email).to be_falsey
    end
  end
  context "creation organization has skip_email" do
    let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["skip_ownership_email"]) }
    let(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: organization) }
    let(:bike) { ownership.bike }
    it "doesn't send email, updates to be send_email false, sends email to the second ownership" do
      ActionMailer::Base.deliveries = []
      expect(ownership.send_email).to be_truthy
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
      expect(ActionMailer::Base.deliveries).to be_empty
      ownership.reload
      expect(ownership.send_email).to be_falsey
      expect(ownership.current?).to be_truthy
      # Second email
      ownership2 = FactoryBot.create(:ownership, bike: bike)
      ownership.reload
      expect(ownership.current?).to be_falsey
      expect(ownership2.send_email).to be_truthy
      expect(ownership2.organization).to be_blank
      expect(ownership2.calculated_send_email).to be_truthy
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(ownership2.id)
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end
  end
end
