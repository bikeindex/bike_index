require "rails_helper"

RSpec.describe EmailHeldBikeNotificationWorker, type: :job do
  before do
    ActionMailer::Base.deliveries = []
  end

  it "triggers emails for every potentially held bike" do
    allow(CustomerMailer).to receive(:held_bike_email).and_call_original
    FactoryBot.create(:stolen_bike)
    # stolen but not abandoned bike
    bike = FactoryBot.create(:stolen_bike, abandoned: false, serial_number: "HELL0")
    # abandoned but not stolen bike with matching normalized serial
    match = FactoryBot.create(:abandoned_bike, stolen: false, serial_number: "HE11O")
    expect(bike.serial_normalized).to eq(match.serial_normalized)
    expect(bike.owner_email).to_not eq(match.owner_email)

    described_class.new.perform

    expect(ActionMailer::Base.deliveries.length).to eq(1)
    expect(CustomerMailer).to have_received(:held_bike_email).once
  end

  it "skips the bike if it's its own match" do
    allow(CustomerMailer).to receive(:held_bike_email).and_call_original

    # same bike with stolen and abandoned set to true (should not trigger)
    FactoryBot.create(:bike, stolen: true, abandoned: true)

    described_class.new.perform

    expect(CustomerMailer).to_not have_received(:held_bike_email)
    expect(ActionMailer::Base.deliveries.length).to eq(0)
  end

  it "skips the bike if a notification for it has already been sent" do
    allow(CustomerMailer).to receive(:held_bike_email).and_call_original

    # stolen but not abandoned bike
    bike = FactoryBot.create(:stolen_bike, abandoned: false, serial_number: "HELL0")
    # abandoned but not stolen bike with matching normalized serial
    FactoryBot.create(:abandoned_bike, stolen: false, serial_number: "HE11O")
    # an already-sent notification
    FactoryBot.create(:customer_contact,
                      bike: bike,
                      user_email: bike.owner_email,
                      kind: :held_bike_notification)

    described_class.new.perform

    expect(CustomerMailer).to_not have_received(:held_bike_email)
    expect(ActionMailer::Base.deliveries.length).to eq(0)
  end
end
