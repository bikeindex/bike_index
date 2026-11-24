require "rails_helper"

RSpec.describe EmailJobs::PosRegistrationMergedJob, type: :job do
  let(:instance) { described_class.new }
  let(:match) { FactoryBot.create(:pos_registration_match, :different_email, status: :merged) }
  let(:user) { match.bike.user }

  before { ActionMailer::Base.deliveries = [] }

  it "emails the owner once" do
    expect {
      instance.perform(match.id)
      instance.perform(match.id)
    }.to change(Notification, :count).by 1
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
    expect(Notification.last).to have_attributes(kind: "pos_registration_merged", notifiable: match, user_id: user.id,
      bike_id: match.pos_bike_id, delivery_status: "delivery_success")
  end

  context "when it doesn't email" do
    context "when the owner asked for no email but theft alerts" do
      before { user.update!(no_non_theft_notification: true) }

      it "doesn't send" do
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "when the owner answered, with the same email" do
      let(:match) { FactoryBot.create(:pos_registration_match, status: :merged) }

      it "doesn't send" do
        instance.perform(match.id)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end
end
