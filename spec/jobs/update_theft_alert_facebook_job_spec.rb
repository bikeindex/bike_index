require "rails_helper"

# Create class stub so it works on CI
class FakeIntegrationClass
  def update_facebook_data(theft_alert)
    new_data = (theft_alert.facebook_data || {}).merge(effective_object_story_id: "NEEWWW")
    theft_alert.update(facebook_data: new_data)
  end
end

RSpec.describe UpdateTheftAlertFacebookJob, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  describe "perform" do
    let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, amount_cents_facebook: 3999) }
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
    let(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, bike: bike, approved: true) }
    let(:facebook_data) { {campaign_id: "222", adset_id: "333", ad_id: "444", activating_at: Time.current.to_i} }
    let(:theft_alert) do
      FactoryBot.create(:theft_alert, :paid,
        theft_alert_plan: theft_alert_plan,
        stolen_record: stolen_record,
        facebook_data: facebook_data,
        start_at: Time.current - 1.minute,
        end_at: Time.current + theft_alert_plan.duration_days_facebook)
    end
    before { stub_const("Facebook::AdsIntegration", FakeIntegrationClass) }

    it "updates the theft_alert and sends a message" do
      stolen_record.reload
      expect(stolen_record).to be_valid
      expect(theft_alert.stolen_record_id).to eq stolen_record.id
      expect(theft_alert.paid?).to be_truthy
      expect(theft_alert.live?).to be_falsey
      expect(theft_alert.missing_location?).to be_falsey
      expect(theft_alert.missing_photo?).to be_falsey
      expect(theft_alert.activateable?).to be_truthy
      expect(theft_alert.notify?).to be_truthy
      expect(theft_alert.status).to eq "pending"
      expect(theft_alert.start_at).to be_present
      expect(theft_alert.end_at).to be_present
      expect(theft_alert.facebook_post_url).to be_blank
      expect(theft_alert.facebook_updated_at).to be_blank

      ActionMailer::Base.deliveries = []
      expect {
        instance.perform(theft_alert.id)
      }.to change(Notification, :count).by 1
      theft_alert.reload
      expect(theft_alert.facebook_post_url).to be_present
      expect(theft_alert.posted?).to be_truthy
      expect(theft_alert.live?).to be_truthy

      expect(theft_alert.notify?).to be_truthy
      expect(ActionMailer::Base.deliveries.count).to eq 1
      notification = theft_alert.notifications.first
      expect(notification.kind).to eq "theft_alert_posted"

      # Calling it again doesn't create a new notification
      expect {
        instance.perform(theft_alert.id)
      }.to_not change(Notification, :count)
    end
    context "no_notify" do
      it "does not notify" do
        theft_alert.update(facebook_data: facebook_data.merge(no_notify: true))
        stolen_record.reload
        expect(stolen_record).to be_valid
        expect(theft_alert.reload.stolen_record_id).to eq stolen_record.id
        expect(theft_alert.paid?).to be_truthy
        expect(theft_alert.live?).to be_falsey
        expect(theft_alert.missing_location?).to be_falsey
        expect(theft_alert.missing_photo?).to be_falsey
        expect(theft_alert.activateable?).to be_truthy
        expect(theft_alert.notify?).to be_falsey
        expect(theft_alert.status).to eq "pending"
        expect(theft_alert.start_at).to be_present
        expect(theft_alert.end_at).to be_present
        expect(theft_alert.facebook_post_url).to be_blank
        expect(theft_alert.facebook_updated_at).to be_blank

        ActionMailer::Base.deliveries = []
        expect {
          instance.perform(theft_alert.id)
        }.to_not change(Notification, :count)
        theft_alert.reload
        expect(theft_alert.facebook_post_url).to be_present
        expect(theft_alert.live?).to be_truthy

        expect(theft_alert.notify?).to be_falsey
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
    context "pending" do
      let(:facebook_data) { {} }
      it "enqueues activate theft worker and exits" do
        theft_alert.reload
        expect(theft_alert.status).to eq "pending"
        expect {
          instance.perform(theft_alert.id)
        }.to change(ActivateTheftAlertJob.jobs, :count).by 1
      end
    end
    context "receive_notifications? false" do
      it "does not create a notification" do
        expect(theft_alert).to be_present
        stolen_record.update(receive_notifications: false)
        expect(theft_alert.reload.notify?).to be_falsey
        expect {
          instance.perform(theft_alert.id)
        }.to_not change(Notification, :count)
      end
    end
    context "no_notify theft_alert" do
      let(:facebook_data) { {campaign_id: "222", adset_id: "333", ad_id: "444", activating_at: Time.current.to_i, no_notify: 1} }
      it "does not create a notification" do
        expect(theft_alert.reload.notify?).to be_falsey
        expect {
          instance.perform(theft_alert.id)
        }.to_not change(Notification, :count)
        expect(theft_alert.reload.notify?).to be_falsey
        expect(theft_alert.facebook_data["no_notify"]).to eq 1
      end
    end
  end
end
