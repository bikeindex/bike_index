require "rails_helper"

RSpec.describe EmailJobs::PosRegistrationMatchJob, type: :job do
  let(:match) { FactoryBot.create(:pos_registration_match) }
  let(:user) { match.bike.user }

  before { ActionMailer::Base.deliveries = [] }

  it "doesn't send while the flag is off" do
    described_class.new.perform(match.id)
    expect(ActionMailer::Base.deliveries.count).to eq 0
  end

  context "with the flag on" do
    before { Flipper.enable(:pos_registration_match_emails) }

    it "emails the owner once" do
      expect {
        described_class.new.perform(match.id)
        described_class.new.perform(match.id)
      }.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
      expect(Notification.last).to have_attributes(kind: "pos_registration_match", notifiable: match, user_id: user.id,
        bike_id: match.pos_bike_id, delivery_status: "delivery_success")
    end

    it "doesn't email a review candidate or a match that's no longer pending" do
      match.update!(review_reasons: ["impounded"])
      described_class.new.perform(match.id)
      match.update!(review_reasons: [], status: :declined)
      described_class.new.perform(match.id)
      expect(ActionMailer::Base.deliveries.count).to eq 0
    end
  end
end
