require "rails_helper"

RSpec.describe EmailHeldBikeNotificationWorker, type: :job do
  before do
    ActionMailer::Base.deliveries = []
  end

  it "triggers emails for every held bike" do
    allow(CustomerMailer).to receive(:held_bike_email).and_call_original
    FactoryBot.create_list(:abandoned_bike, 2)
    FactoryBot.create(:stolen_bike)

    described_class.new.perform

    expect(ActionMailer::Base.deliveries.length).to eq(2)
    expect(CustomerMailer).to have_received(:held_bike_email).twice
  end
end
