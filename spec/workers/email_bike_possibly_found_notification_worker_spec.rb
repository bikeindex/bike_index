require "rails_helper"

RSpec.describe EmailBikePossiblyFoundNotificationWorker, type: :job do
  before { ActionMailer::Base.deliveries = [] }

  it "triggers an email for the given bike" do
    allow(CustomerMailer).to receive(:bike_possibly_found_email).and_call_original
    # stolen bike with no match
    FactoryBot.create(:stolen_bike)

    # stolen but not abandoned bike with matches
    bike = FactoryBot.create(:stolen_bike, abandoned: false, serial_number: "HELL0")

    # abandoned but not stolen bike with matching normalized serial
    match = FactoryBot.create(:abandoned_bike, stolen: false, serial_number: "HE11O")
    expect(bike.serial_normalized).to eq(match.serial_normalized)
    expect(bike.owner_email).to_not eq(match.owner_email)

    described_class.new.perform(bike.id, match.class, match.id)

    expect(ActionMailer::Base.deliveries.length).to eq(1)
    expect(CustomerMailer).to have_received(:bike_possibly_found_email).once
  end

  it "skips the bike if it's its own match" do
    allow(CustomerMailer).to receive(:bike_possibly_found_email).and_call_original

    # same bike with stolen and abandoned set to true (should not trigger)
    bike = FactoryBot.create(:bike, stolen: true, abandoned: true)

    described_class.new.perform(bike.id, bike.class, bike.id)

    expect(CustomerMailer).to_not have_received(:bike_possibly_found_email)
    expect(ActionMailer::Base.deliveries.length).to eq(0)
  end

  it "skips the bike if a notification for it has already been sent" do
    bike = FactoryBot.create(:stolen_bike, abandoned: false, serial_number: "HELL0")
    match = FactoryBot.create(:abandoned_bike, stolen: false, serial_number: "HE11O")

    # an already-sent notification
    contact = CustomerContact.build_bike_possibly_found_notification(bike, match)
    contact.email = CustomerMailer.bike_possibly_found_email(contact)
    contact.save

    allow(CustomerMailer).to receive(:bike_possibly_found_email).and_call_original

    described_class.new.perform(bike.id, match.class, match.id)

    expect(CustomerMailer).to_not have_received(:bike_possibly_found_email)
    expect(ActionMailer::Base.deliveries.length).to eq(0)
  end
end
