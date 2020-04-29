require "rails_helper"

RSpec.describe ProcessParkingNotificationWorker, type: :job do
  let(:subject) { described_class }
  let(:instance) { subject.new }
  before { ActionMailer::Base.deliveries = [] }

  describe "perform" do
    let(:initial) { FactoryBot.create(:parking_notification_organized, created_at: Time.current - 4.days, kind: "appears_abandoned_notification") }
    let(:bike) { initial.bike }
    let(:user) { initial.user }
    let(:organization) { initial.organization }
    let(:initial_record_id) { initial.id }
    let(:kind2) { "appears_abandoned_notification" }
    let!(:parking_notification2) { FactoryBot.create(:parking_notification, user: user, bike: bike, organization: organization, created_at: Time.current - 2.days, kind: kind2, initial_record_id: initial_record_id, delivery_status: "email_success") }
    context "impound record" do
      let(:parking_notification3) { FactoryBot.build(:parking_notification, user: user, bike: bike, organization: organization, kind: "impound_notification", initial_record: initial) }
      it "updates the other parking_notifications, creates the impound record" do
        initial.reload
        initial.update_attributes(updated_at: Time.current) # Because of calculated_status
        initial.reload
        parking_notification2.reload
        bike.reload
        expect(bike.status).to eq "status_abandoned"
        expect(initial.status).to eq "replaced"
        expect(parking_notification2.status).to eq "current"
        expect(parking_notification2.delivery_status).to eq "email_success"
        expect(parking_notification2.organization_id).to be_present
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
        expect(parking_notification3.kind).to eq "impound_notification"
        expect(parking_notification3.impound_record).to be_present
        expect(parking_notification3.status).to eq "impounded"
        impound_record = parking_notification3.impound_record
        expect(impound_record.bike).to eq bike
        expect(impound_record.organization).to eq organization
        expect(impound_record.user).to eq user
        expect(impound_record.parking_notification).to eq parking_notification3
        bike.reload
        expect(bike.status).to eq "status_impounded"
        expect(bike.current_impound_record).to eq impound_record
        expect(bike.impounded?).to be_truthy

        initial.reload
        parking_notification2.reload
        expect(initial.impound_record).to eq impound_record
        expect(initial.kind).to eq "appears_abandoned_notification"
        expect(initial.status).to eq "impounded"
        expect(parking_notification2.delivery_status).to eq "email_success"
        expect(parking_notification2.status).to eq "impounded"
        expect(parking_notification2.impound_record).to eq impound_record
        expect(parking_notification2.kind).to eq "appears_abandoned_notification"
      end
    end
    context "retrieved" do
      it "updates the other parking_notifications" do
        initial.reload
        initial.update_attributes(updated_at: Time.current) # Because of calculated_status
        initial.reload
        parking_notification2.reload
        bike.reload
        expect(bike.status).to eq "status_abandoned"
        expect(initial.status).to eq "replaced"
        expect(parking_notification2.status).to eq "current"
        expect(initial.associated_retrieved_notification).to be_nil
        Sidekiq::Worker.clear_all
        expect do
          initial.mark_retrieved!(retrieved_by_id: user.id, retrieved_kind: "link_token_recovery")
        end.to change(ProcessParkingNotificationWorker.jobs, :size).by(1)
        ProcessParkingNotificationWorker.drain
        initial.reload
        parking_notification2.reload

        expect(initial.status).to eq "retrieved"
        expect(initial.resolved_at).to be_within(10).of Time.current
        expect(initial.retrieved_by).to eq user
        expect(initial.associated_retrieved_notification).to eq initial

        expect(parking_notification2.status).to eq "retrieved"
        expect(parking_notification2.resolved_at).to be_within(1).of initial.resolved_at
        expect(parking_notification2.associated_retrieved_notification).to eq initial
      end
    end

    context "other active notification for bike, from organization" do
      let(:initial_record_id) { nil }
      let(:parking_notification3) { FactoryBot.create(:parking_notification, bike: bike) }
      it "does nothing to the other notification, closes all on retrieval" do
        initial.reload
        parking_notification2.reload
        expect(initial.associated_notifications).to eq([])
        expect(parking_notification2.associated_notifications).to eq([])
        expect(parking_notification3.associated_notifications).to eq([])
        expect(initial.notifications_from_period.pluck(:id)).to match_array([initial.id, parking_notification2.id])
        instance.perform(parking_notification2.id)
        initial.reload
        parking_notification2.reload
        parking_notification3.reload
        expect(initial.associated_notifications.pluck(:id)).to match_array([])
        expect(parking_notification2.associated_notifications.pluck(:id)).to match_array([])
        expect(parking_notification3.associated_notifications.pluck(:id)).to match_array([])
        expect(parking_notification3.current?).to be_truthy
        expect(parking_notification2.replaced?).to be_truthy
        expect(parking_notification2.current?).to be_truthy
        expect(initial.current?).to be_truthy
        expect(initial.notifications_from_period.pluck(:id)).to match_array([initial.id, parking_notification2.id])
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          parking_notification2.mark_retrieved!(retrieved_kind: "link_token_recovery", resolved_at: Time.current - 5.minutes)
        end
        initial.reload
        parking_notification2.reload
        parking_notification3.reload
        expect(initial.associated_notifications.pluck(:id)).to match_array([])
        expect(parking_notification2.associated_notifications.pluck(:id)).to match_array([])
        expect(parking_notification3.associated_notifications.pluck(:id)).to match_array([])
        expect(parking_notification3.current?).to be_truthy

        expect(parking_notification2.associated_retrieved_notification).to eq parking_notification2
        expect(parking_notification2.retrieved?).to be_truthy
        expect(parking_notification2.current?).to be_falsey

        expect(initial.current?).to be_falsey
        expect(initial.associated_retrieved_notification).to be_blank
        expect(initial.resolved_otherwise?).to be_truthy
        expect(initial.resolved_at).to be_within(5).of parking_notification2.resolved_at

        # Test the notifications_from_period here
        new_parking_notification = FactoryBot.create(:parking_notification, user: user, bike: bike, organization: organization, kind: kind2)
        expect(new_parking_notification.notifications_from_period.pluck(:id)).to eq([new_parking_notification.id])

        parking_notification2.reload
        expect(parking_notification2.notifications_from_period.pluck(:id)).to match_array([initial.id, parking_notification2.id])
      end
    end
  end


  describe "sending email" do
    let(:bike) { FactoryBot.create(:ownership).bike }
    let(:parking_notification) { FactoryBot.create(:parking_notification_organized, delivery_status: delivery_status, bike: bike) }
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
