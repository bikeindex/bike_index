require "rails_helper"

RSpec.describe EnqueueBikePossiblyFoundNotificationsWorker, type: :job do
  context "given no bikes with matches" do
    it "does not enqueue any notification jobs" do
      allow(Bike).to receive(:possibly_found_with_match).and_return([])
      allow(Bike).to receive(:possibly_found_externally_with_match).and_return([])
      expect(EmailBikePossiblyFoundNotificationWorker.jobs.length).to eq(0)

      described_class.new.perform

      expect(EmailBikePossiblyFoundNotificationWorker.jobs.length).to eq(0)
    end
  end

  context "given bikes with matches" do
    it "enqueues a notification job for each match" do
      FactoryBot.create(:stolen_bike_in_amsterdam, abandoned: false, serial_number: "hello")
      FactoryBot.create(:abandoned_bike, stolen: false, serial_number: "hel1o")
      FactoryBot.create(:external_registry_bike, serial_number: "he1l0")
      expect(EmailBikePossiblyFoundNotificationWorker.jobs.length).to eq(0)

      described_class.new.perform

      expect(EmailBikePossiblyFoundNotificationWorker.jobs.length).to eq(2)
    end
  end
end
