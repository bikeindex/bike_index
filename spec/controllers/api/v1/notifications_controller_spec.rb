require 'spec_helper'

describe Api::V1::NotificationsController do
  describe 'send_notification_email' do
    it "returns correct code if authentication fails" do
      bike = FactoryGirl.create(:bike)
      options = { some_stuff: 'things',
        other_stuff: 'Things',
        bike_id: bike.id
      } 
      post :create, options
      expect(response.code).to eq("401")
    end

    it "sends an email if the authorization works" do
      expect(CustomerContact.count).to eq(0)
      stolen_record = FactoryGirl.create(:stolen_record)
      options = {
        access_token: ENV['NOTIFICATIONS_API_KEY'],
        notification_hash: {
          notification_type: 'stolen_twitter_alerter',
          bike_id: stolen_record.bike.id,
          tweet_id: 69,
          tweet_string: "STOLEN - something special",
          tweet_account_screen_name: "bikeindex",
          tweet_account_name: "Bike Index",
          tweet_account_image: "https://pbs.twimg.com/profile_images/3384343656/33893b31d39d69fb4b85912489c497b0_bigger.png",
          :retweet_screen_names=>[]
        }
      }
      expect {
        post :create, options, format: :json
      }.to change(EmailStolenBikeAlertWorker.jobs, :size).by(1)
      expect(response.code).to eq("200")
      expect(CustomerContact.count).to eq(1)
      customer_contact = CustomerContact.first
      expect(customer_contact.info_hash[:bike_id].to_i).to eq(stolen_record.bike.id)
      expect(customer_contact.info_hash[:tweet_string]).to eq('STOLEN - something special')
      expect(customer_contact.info_hash[:notification_type]).to eq('stolen_twitter_alerter')
    end

    it "sends a recovered email if the authorization works" do
      expect(CustomerContact.count).to eq(0)
      stolen_record = FactoryGirl.create(:stolen_record)
      bike = stolen_record.bike
      bike.update_attribute :recovered, true
      options = {
        access_token: ENV['NOTIFICATIONS_API_KEY'],
        notification_hash: {
          notification_type: 'stolen_twitter_alerter',
          bike_id: stolen_record.bike.id,
          tweet_id: 69,
          tweet_string: "FOUND - something special",
          tweet_account_screen_name: "bikeindex",
          tweet_account_name: "Bike Index",
          tweet_account_image: "https://pbs.twimg.com/profile_images/3384343656/33893b31d39d69fb4b85912489c497b0_bigger.png",
          :retweet_screen_names=>[]
        }
      }
      expect {
        post :create, options, format: :json
      }.to change(EmailStolenBikeAlertWorker.jobs, :size).by(1)
      expect(response.code).to eq("200")
      expect(CustomerContact.count).to eq(1)
      customer_contact = CustomerContact.first
      expect(customer_contact.info_hash[:bike_id].to_i).to eq(stolen_record.bike.id)
      expect(customer_contact.info_hash[:tweet_string]).to eq('FOUND - something special')
      expect(customer_contact.title).to eq('We tweeted about the bike you recovered!')
      expect(customer_contact.info_hash[:notification_type]).to eq('stolen_twitter_alerter')
    end

  end


    
end
