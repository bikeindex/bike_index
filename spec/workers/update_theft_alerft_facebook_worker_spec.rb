require "rails_helper"

# Create class stub so it works on CI
class FakeIntegrationClass
  def update_facebook_data(theft_alert)
    new_data = (theft_alert.facebook_data || {}).merge(effective_object_story_id: "NEEWWW")
    theft_alert.update(facebook_data: new_data)
  end

  def create_for(theft_alert)
    new_data = (theft_alert.facebook_data || {}).merge(campaign_id: "111", adset_id: "3333", ad_id: "5555")
    theft_alert.update(facebook_data: new_data)
  end
end

RSpec.describe UpdateTheftAlertFacebookWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, amount_cents_facebook: 3999) }
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
    let(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, bike: bike, approved: true) }
    let(:theft_alert) { FactoryBot.create(:theft_alert, :paid, theft_alert_plan: theft_alert_plan, stolen_record: stolen_record, facebook_data: facebook_data) }
    let(:facebook_data) { {campaign_id: "222", adset_id: "333", ad_id: "444", activating_at: Time.current.to_i} }

    before { stub_const("Facebook::AdsIntegration", FakeIntegrationClass) }

    it "updates the theft_alert and sends a messag" do
      stolen_record.reload
      expect(stolen_record).to be_valid
      expect(theft_alert.stolen_record_id).to eq stolen_record.id
      expect(theft_alert.paid?).to be_truthy
      expect(theft_alert.missing_location?).to be_falsey
      expect(theft_alert.missing_photo?).to be_falsey
      expect(theft_alert.activateable?).to be_truthy
      expect(theft_alert.notify?).to be_truthy
      expect(theft_alert.status).to eq "pending"
      expect(theft_alert.begin_at).to be_blank
      expect(theft_alert.facebook_post_url).to be_blank

      ActionMailer::Base.deliveries = []
      expect {
        instance.perform(theft_alert.id)
      }.to change(Notification, :count).by 1
      theft_alert.reload
      expect(theft_alert.facebook_post_url).to be_present

      expect(ActionMailer::Base.deliveries.count).to eq 1
      notification = theft_alert.notifications.first
      expect(notification.kind).to eq "theft_alert_posted"

      # Calling it again doesn't create a new notification
      expect {
        instance.perform(theft_alert.id)
      }.to_not change(Notification, :count)
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
    context "earlier theft_alert" do
      it "does not create a notification" do
        theft_alert.update(created_at: TimeParser.parse("2021-7-6"))
        expect(theft_alert.reload.notify?).to be_falsey
        expect {
          instance.perform(theft_alert.id)
        }.to_not change(Notification, :count)
      end
    end
  end
end
