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
    let(:organization) { FactoryBot.create(:organization) }
    let!(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: organization) }
    let(:bike) { ownership.bike }
    let(:ownership2) { FactoryBot.build(:ownership, bike: bike) }
    before { organization.update_attribute :enabled_feature_slugs, ["skip_ownership_email"] }
    it "doesn't send email, updates to be send_email false, sends email to the second ownership" do
      ownership.reload
      expect(ownership.send_email).to be_truthy
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(ownership.id)
      expect(ActionMailer::Base.deliveries).to be_empty
      ownership.reload
      expect(ownership.send_email).to be_falsey
      # Second email o
      ownership2.save
      ownership2.reload
      expect(ownership2.send_email).to be_truthy
      ActionMailer::Base.deliveries = []
      EmailOwnershipInvitationWorker.new.perform(ownership2.id)
      expect(ActionMailer::Base.deliveries).to_not be_empty
    end
  end
end
