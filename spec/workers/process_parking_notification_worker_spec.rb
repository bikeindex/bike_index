require "rails_helper"

RSpec.describe ProcessParkingNotificationWorker, type: :job do
  let(:subject) { described_class }
  let(:instance) { subject.new }
  before { ActionMailer::Base.deliveries = [] }

  # repeat_parking_notifications.map(&:update)
  # Create impound record

  describe "updating associated records" do
    let(:initial) { FactoryBot.create(:parking_notification_organized, updated_at: Time.current - 4.days, kind: "appears_abandoned") }
    let(:bike) { initial.bike }
    let(:user) { initial.user }
    let(:organization) { initial.organization }
    let(:parking_notification2) { FactoryBot.create(:parking_notification_organized, user: user, bike: bike, organization: organization, updated_at: Time.current - 2.days, kind: "appears_abandoned", initial_record: initial) }
    let(:parking_notification3) { FactoryBot.build(:parking_notification_organized, user: user, bike: bike, organization: organization, kind: "impounded", initial_record: initial) }
    it "updates the other parking_notifications, creates the impound record" do
      initial.reload
      parking_notification2.reload
      bike.reload
      expect(bike.status).to eq "status_abandoned"
      expect(initial.updated_at).to be < (Time.current - 3.days)
      expect(parking_notification2.updated_at).to be < (Time.current - 1.days)
      Sidekiq::Worker.clear_all
      expect do
        parking_notification3.save
        parking_notification3.reload
        expect(parking_notification3.associated_notifications.pluck(:id)).to match_array([initial.id, parking_notification2.id])
      end.to change(ProcessParkingNotificationWorker.jobs, :size).by(1)
      expect(parking_notification3.delivery_status).to be_blank
      # Ensure we don't accidentally reloop things
      expect do
        subject.drain
      end.to change(ProcessParkingNotificationWorker.jobs, :size).by(-1)
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      parking_notification3.reload
      expect(parking_notification3.delivery_status).to eq "email_success"
      expect(parking_notification3.kind).to eq "impounded"
      expect(parking_notification3.impound_record).to be_present
      impound_record = parking_notification3.impound_record
      expect(impound_record.bike).to eq bike
      expect(impound_record.organization).to eq organization
      expect(impound_record.user).to eq user
      expect(impound_record.parking_notifications.pluck(:id)).to match_array([initial.id, parking_notification2.id, parking_notification3.id])
      bike.reload
      expect(bike.status).to eq "status_impounded"
      expect(bike.current_impound_record).to eq impound_record
      expect(bike.impounded?).to be_truthy

      initial.reload
      parking_notification2.reload
      expect(initial.impound_record).to eq impound_record
      expect(initial.kind).to eq "appears_abandoned"
      expect(parking_notification2.impound_record).to eq impound_record
      expect(parking_notification2.kind).to eq "appears_abandoned"
    end
  end


  describe "sending email" do
    let(:bike) { FactoryBot.create(:ownership).bike }
    let(:parking_notification) { FactoryBot.create(:parking_notification, delivery_status: delivery_status, bike: bike) }
    let(:delivery_status) { nil }

    it "sends an email" do
      expect(parking_notification.send_email?).to be_truthy
      instance.perform(parking_notification.id)
      expect(ActionMailer::Base.deliveries.empty?).to be_falsey
      parking_notification.reload
      expect(parking_notification.delivery_status).to be_present
    end

    context "delivery failed" do
      let(:delivery_status)  { "email_failure" }
      it "does not send" do
        expect(parking_notification.send_email?).to be_truthy
        instance.perform(parking_notification.id)
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      end
    end

    context "delivery succeeded" do
      let(:delivery_status)  { "email_success" }
      it "does not send" do
        instance.perform(parking_notification.id)
        expect(ActionMailer::Base.deliveries.empty?).to be_truthy
      end
    end
  end
end
