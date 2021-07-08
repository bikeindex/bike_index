require "rails_helper"

RSpec.describe UpdateTheftAlertFacebookWorker, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, amount_cents_facebook: 3999) }
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Salsa") }
    let(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, bike: bike, approved: true) }
    let(:theft_alert) { FactoryBot.create(:theft_alert, :paid, theft_alert_plan: theft_alert_plan, stolen_record: stolen_record, facebook_data: facebook_data) }
    let(:facebook_data) { {campaign_id: "222", adset_id: "333", ad_id: "444", activating_at: Time.current.to_i} }

    # Stub class so it works in CI
    class Facebook::AdsIntegration
      def update_facebook_data(theft_alert)
        new_data = theft_alert.facebook_data || {}
        theft_alert.update(facebook_data: new_data.merge(effective_object_story_id: "NEEWWW"))
      end
    end

    it "updates the theft_alert and sends a messag" do
      stolen_record.reload
      expect(stolen_record).to be_valid
      expect(theft_alert.stolen_record_id).to eq stolen_record.id
      expect(theft_alert.paid?).to be_truthy
      expect(theft_alert.missing_location?).to be_falsey
      expect(theft_alert.missing_photo?).to be_falsey
      expect(theft_alert.activateable?).to be_truthy
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
    end
  end
end
