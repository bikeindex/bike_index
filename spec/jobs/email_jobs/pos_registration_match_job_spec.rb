require "rails_helper"

RSpec.describe EmailJobs::PosRegistrationMatchJob, type: :job do
  let(:match) { FactoryBot.create(:pos_registration_match) }
  let(:user) { match.bike.user }

  before { ActionMailer::Base.deliveries = [] }

  it "doesn't send while skipped" do
    stub_const("ENV", ENV.to_h.merge(described_class.skip_env_var => "true"))
    described_class.new.perform(match.id)
    expect(ActionMailer::Base.deliveries.count).to eq 0
  end

  it "emails the owner once" do
    expect {
      described_class.new.perform(match.id)
      described_class.new.perform(match.id)
    }.to change(Notification, :count).by 1
    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([[user.email]])
    expect(Notification.last).to have_attributes(kind: "pos_registration_match", notifiable: match, user_id: user.id,
      bike_id: match.pos_bike_id, delivery_status: "delivery_success")
  end

  it "emails about a POS registration the owner hid" do
    match.pos_bike.update_column(:user_hidden, true)
    described_class.new.perform(match.id)
    expect(ActionMailer::Base.deliveries.count).to eq 1
  end

  it "records a theft since the match and doesn't email" do
    FactoryBot.create(:stolen_bike, serial_number: match.bike.serial_number)
    described_class.new.perform(match.id)
    expect(match.reload.review_reasons).to eq ["stolen_history"]
    expect(ActionMailer::Base.deliveries.count).to eq 0
  end

  it "doesn't email once the POS registration is someone else's" do
    BikeServices::OwnershipTransferer.find_or_create(match.pos_bike, updator: user, new_owner_email: "new-owner@example.com")
    described_class.new.perform(match.id)
    expect(ActionMailer::Base.deliveries.count).to eq 0
  end

  it "doesn't email a review candidate or a match that's no longer pending" do
    match.update!(review_reasons: ["impounded"])
    described_class.new.perform(match.id)
    match.update!(review_reasons: [], status: :declined)
    described_class.new.perform(match.id)
    expect(ActionMailer::Base.deliveries.count).to eq 0
  end
end
