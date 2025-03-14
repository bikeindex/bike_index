require "rails_helper"

RSpec.describe Email::TheftAlertNotificationJob, type: :job do
  let(:instance) { described_class.new }

  describe ".perform" do
    let(:theft_alert) { FactoryBot.create(:theft_alert_paid, facebook_data: facebook_data) }
    let(:facebook_data) { {} }
    before { ActionMailer::Base.deliveries = [] }

    it "sends email to admins" do
      expect(theft_alert.notifications.count).to eq 0

      expect {
        instance.perform(theft_alert.id, "theft_alert_recovered")
      }.to(change { ActionMailer::Base.deliveries.length }.by(1))

      expect(theft_alert.notifications.count).to eq 1
      notification = theft_alert.notifications.last
      expect(notification.kind).to eq "theft_alert_recovered"
      expect(notification.delivery_success?).to be_truthy
      expect(notification.bike_id).to eq theft_alert.stolen_record.bike_id
      expect(notification.theft_alert?).to be_truthy
      expect(notification.sender&.id).to be_blank
      expect(notification.sender_display_name).to eq "auto"

      # Doesn't redeliver
      expect {
        instance.perform(theft_alert.id, "theft_alert_recovered")
      }.to(change { ActionMailer::Base.deliveries.length }.by(0))
    end

    context "theft_alert_posted" do
      let(:facebook_data) { {campaign_id: "aaa", adset_id: "bbb", ad_id: "cccc", effective_object_story_id: "33333cccc877314142"} }

      it "sends email" do
        expect {
          instance.perform(theft_alert.id, "theft_alert_posted")
        }.to change(Notification, :count).by(1)
        theft_alert.reload
        notification = theft_alert.notifications.last
        expect(notification.kind).to eq "theft_alert_posted"
        expect(notification.delivery_success?).to be_truthy

        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq "Your promoted alert advertisement is live!"
        expect(mail.from.count).to eq(1)
        expect(mail.from.first).to eq("gavin@bikeindex.org")
        # Not currently including a link to the ad, because it wasn't working
        # expect(mail.body.encoded).to match(facebook_data[:effective_object_story_id])

        # Doesn't redeliver
        expect {
          instance.perform(theft_alert.id, "theft_alert_posted")
        }.to change(Notification, :count).by(0)
      end
    end
  end
end
