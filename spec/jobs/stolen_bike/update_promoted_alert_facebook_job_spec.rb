require "rails_helper"

# Create class stub so it works on CI
class FakeIntegrationClass
  def update_facebook_data(promoted_alert)
    new_data = (promoted_alert.facebook_data || {}).merge(effective_object_story_id: "NEEWWW")
    promoted_alert.update(facebook_data: new_data)
  end
end

RSpec.describe StolenBike::UpdatePromotedAlertFacebookJob, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  describe "perform" do
    let(:promoted_alert_plan) { FactoryBot.create(:promoted_alert_plan, amount_cents_facebook: 3999) }
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
    let(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, bike: bike, approved: true) }
    let(:facebook_data) { {campaign_id: "222", adset_id: "333", ad_id: "444", activating_at: Time.current.to_i} }
    let(:start_at) { Time.current - 1.minute }
    let(:end_at) { Time.current + promoted_alert_plan.duration_days_facebook }
    let(:promoted_alert) do
      FactoryBot.create(:promoted_alert, :paid,
        promoted_alert_plan:,
        stolen_record:,
        facebook_data:,
        start_at:,
        end_at:)
    end
    before { stub_const("Facebook::AdsIntegration", FakeIntegrationClass) }

    it "updates the promoted_alert and sends a message" do
      stolen_record.reload
      expect(stolen_record).to be_valid
      expect(promoted_alert.reload.stolen_record_id).to eq stolen_record.id
      expect(promoted_alert.paid?).to be_truthy
      expect(promoted_alert.live?).to be_falsey
      expect(promoted_alert.missing_location?).to be_falsey
      expect(promoted_alert.missing_photo?).to be_falsey
      expect(promoted_alert.activateable?).to be_truthy
      expect(promoted_alert.notify?).to be_truthy
      expect(promoted_alert.status).to eq "pending"
      expect(promoted_alert.start_at).to be_present
      expect(promoted_alert.end_at).to be_present
      expect(promoted_alert.facebook_post_url).to be_blank
      expect(promoted_alert.facebook_updated_at).to be_blank
      expect(promoted_alert.should_update_facebook?).to be_truthy

      # It's enqueued
      expect {
        instance.perform
      }.to change(StolenBike::UpdatePromotedAlertFacebookJob.jobs, :count).by 1

      ActionMailer::Base.deliveries = []
      expect {
        instance.perform(promoted_alert.id)
      }.to change(Notification, :count).by 1
      promoted_alert.reload
      expect(promoted_alert.facebook_post_url).to be_present
      expect(promoted_alert.posted?).to be_truthy
      expect(promoted_alert.live?).to be_truthy

      expect(promoted_alert.notify?).to be_truthy
      expect(ActionMailer::Base.deliveries.count).to eq 1
      notification = promoted_alert.notifications.first
      expect(notification.kind).to eq "promoted_alert_posted"

      # Calling it again doesn't create a new notification
      expect {
        instance.perform(promoted_alert.id)
      }.to_not change(Notification, :count)
    end
    context "with facebook_update_at set" do
      it "also enqueues" do
        promoted_alert.update(facebook_updated_at: Time.current - 6.hours)
        expect(PromotedAlert.facebook_updateable.pluck(:id)).to eq([promoted_alert.id])
        expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([promoted_alert.id])
        expect(promoted_alert.reload.should_update_facebook?).to be_truthy

        # It's enqueued
        expect {
          instance.perform
        }.to change(StolenBike::UpdatePromotedAlertFacebookJob.jobs, :count).by 1
      end
    end
    context "no_notify" do
      it "does not notify" do
        promoted_alert.update(facebook_data: facebook_data.merge(no_notify: true))
        stolen_record.reload
        expect(stolen_record).to be_valid
        expect(promoted_alert.reload.stolen_record_id).to eq stolen_record.id
        expect(promoted_alert.paid?).to be_truthy
        expect(promoted_alert.live?).to be_falsey
        expect(promoted_alert.missing_location?).to be_falsey
        expect(promoted_alert.missing_photo?).to be_falsey
        expect(promoted_alert.activateable?).to be_truthy
        expect(promoted_alert.notify?).to be_falsey
        expect(promoted_alert.status).to eq "pending"
        expect(promoted_alert.start_at).to be_present
        expect(promoted_alert.end_at).to be_present
        expect(promoted_alert.facebook_post_url).to be_blank
        expect(promoted_alert.facebook_updated_at).to be_blank
        expect(promoted_alert.should_update_facebook?).to be_truthy

        ActionMailer::Base.deliveries = []
        expect {
          instance.perform(promoted_alert.id)
        }.to_not change(Notification, :count)
        promoted_alert.reload
        expect(promoted_alert.facebook_post_url).to be_present
        expect(promoted_alert.live?).to be_truthy

        expect(promoted_alert.notify?).to be_falsey
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
    context "pending" do
      let(:facebook_data) { {} }
      it "enqueues activate theft worker and exits" do
        promoted_alert.reload
        expect(promoted_alert.status).to eq "pending"
        expect(promoted_alert.should_update_facebook?).to be_falsey
        # It's isn't enqueued
        expect {
          instance.perform
        }.to change(StolenBike::UpdatePromotedAlertFacebookJob.jobs, :count).by 0
        # But if it's processed, it runs activate
        expect {
          instance.perform(promoted_alert.id)
        }.to change(StolenBike::ActivatePromotedAlertJob.jobs, :count).by 1
      end
      context "failed_to_activate" do
        let(:start_at) { nil }
        let(:end_at) { nil }
        let(:facebook_data) { {activating_at: (Time.current - 6.minutes).to_i} }
        it "enqueues activate theft worker and exits" do
          promoted_alert.reload
          expect(promoted_alert.failed_to_activate?).to be_truthy
          expect(promoted_alert.should_update_facebook?).to be_falsey
          expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([promoted_alert.id])
          # It's enqueued
          expect {
            instance.perform
          }.to change(StolenBike::UpdatePromotedAlertFacebookJob.jobs, :count).by 1
          # when processed, it runs activate
          expect {
            instance.perform(promoted_alert.id)
          }.to change(StolenBike::ActivatePromotedAlertJob.jobs, :count).by 1
        end
      end
    end
    context "receive_notifications? false" do
      it "does not create a notification" do
        expect(promoted_alert).to be_present
        stolen_record.update(receive_notifications: false)
        expect(promoted_alert.reload.notify?).to be_falsey
        expect {
          instance.perform(promoted_alert.id)
        }.to_not change(Notification, :count)
      end
    end
    context "no_notify promoted_alert" do
      let(:facebook_data) { {campaign_id: "222", adset_id: "333", ad_id: "444", activating_at: Time.current.to_i, no_notify: 1} }
      it "does not create a notification" do
        expect(promoted_alert.reload.notify?).to be_falsey
        expect {
          instance.perform(promoted_alert.id)
        }.to_not change(Notification, :count)
        expect(promoted_alert.reload.notify?).to be_falsey
        expect(promoted_alert.facebook_data["no_notify"]).to eq 1
      end
    end
  end
end
