require "rails_helper"

RSpec.describe ScheduledBikePossiblyFoundNotificationJob, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  context "given no bikes with matches" do
    it "does not enqueue any notification jobs" do
      allow(Bike).to receive(:possibly_found_with_match).and_return([])
      allow(Bike).to receive(:possibly_found_externally_with_match).and_return([])
      expect(EmailBikePossiblyFoundNotificationJob.jobs.length).to eq(0)

      described_class.new.perform

      expect(EmailBikePossiblyFoundNotificationJob.jobs.length).to eq(0)
    end
  end

  context "given bikes with matches" do
    it "enqueues a notification job for each match" do
      FactoryBot.create(:stolen_bike_in_amsterdam, serial_number: "hello")
      abandoned_bike = FactoryBot.create(:bike, serial_number: "hel1o")
      FactoryBot.create(:parking_notification, kind: "appears_abandoned_notification", bike: abandoned_bike)
      FactoryBot.create(:external_registry_bike, serial_number: "he1l0")
      expect(EmailBikePossiblyFoundNotificationJob.jobs.length).to eq(0)
      abandoned_bike.reload
      expect(abandoned_bike.parking_notifications.active.appears_abandoned_notification.any?).to be_truthy
      expect(abandoned_bike.status_abandoned?).to be_truthy
      expect(Bike.status_abandoned.pluck(:id)).to eq([abandoned_bike.id])

      described_class.new.perform

      expect(EmailBikePossiblyFoundNotificationJob.jobs.length).to eq(2)
    end
  end
end
