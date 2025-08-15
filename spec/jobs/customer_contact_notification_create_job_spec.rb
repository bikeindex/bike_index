require "rails_helper"

RSpec.describe CustomerContactNotificationCreateJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:customer_contact) { FactoryBot.build(:customer_contact) }
    it "It enqueues on create" do
      expect {
        customer_contact.save
      }.to change(CustomerContactNotificationCreateJob.jobs, :count).by 1
      expect {
        instance.perform(customer_contact.id)
        instance.perform(customer_contact.id)
        instance.perform(customer_contact.id)
      }.to change(Notification, :count).by 1
      customer_contact.reload
      notification = customer_contact.notification
      expect(notification.user_id).to be_blank
      expect(notification.kind).to eq customer_contact.kind
      expect(notification.delivery_success?).to be_truthy
      expect(notification.bike_id).to eq customer_contact.bike_id
      expect(notification.message_channel_target).to eq customer_contact.user_email
      expect(notification.sender).to eq customer_contact.creator
      expect(notification.sender_display_name).to eq customer_contact.creator.display_name
    end

    it "sends an email" do
      bike = FactoryBot.create(:stolen_bike)
      FactoryBot.create(:ownership, bike: bike)
      info_hash = {
        notification_type: "stolen_twitter_alerter",
        bike_id: bike.id,
        tweet_id: 69,
        tweet_string: "STOLEN - something special",
        tweet_account_screen_name: "bikeindex",
        tweet_account_name: "Bike Index",
        tweet_account_image: "https://pbs.twimg.com/profile_images/3384343656/33893b31d39d69fb4b85912489c497b0_bigger.png",
        location: "Everywhere",
        retweet_screen_names: ["someother_screename"]
      }
      customer_contact = FactoryBot.create(:customer_contact, bike: bike, info_hash: info_hash)
      ActionMailer::Base.deliveries = []
      expect do
        instance.perform(customer_contact.id)
      end.to change(Notification, :count).by 1
      expect(ActionMailer::Base.deliveries).not_to be_empty
      expect(Notification.last.delivery_status).to eq "delivery_success"
    end

    context "stolen bike has receive_notifications false" do
      it "does not send an email if the stolen bike has receive_notifications false" do
        stolen_record = FactoryBot.create(:stolen_record, receive_notifications: false)
        customer_contact = FactoryBot.create(:customer_contact, bike: stolen_record.bike)
        ActionMailer::Base.deliveries = []
        expect do
          instance.perform(customer_contact.id)
        end.to change(Notification, :count).by 0
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end
  end
end
