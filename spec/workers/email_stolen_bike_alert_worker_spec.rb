require 'spec_helper'

describe EmailStolenBikeAlertWorker do
  it { is_expected.to be_processed_in :notify }

  describe 'perform' do
    it 'sends an email' do
      stolenRecord = FactoryGirl.create(:stolenRecord)
      info_hash = {
        notification_type: 'stolen_twitter_alerter',
        bike_id: stolenRecord.bike.id,
        tweet_id: 69,
        tweet_string: 'STOLEN - something special',
        tweet_account_screen_name: 'bikeindex',
        tweet_account_name: 'Bike Index',
        tweet_account_image: 'https://pbs.twimg.com/profile_images/3384343656/33893b31d39d69fb4b85912489c497b0_bigger.png',
        location: 'Everywhere',
        retweet_screen_names: ['someother_screename']
      }
      customer_contact = FactoryGirl.create(:customer_contact, bike: stolenRecord.bike, info_hash: info_hash)
      ActionMailer::Base.deliveries = []
      EmailStolenBikeAlertWorker.new.perform(customer_contact.id)
      expect(ActionMailer::Base.deliveries).not_to be_empty
    end

    it 'does not send an email if the stolen bike has receive_notifications false' do
      stolenRecord = FactoryGirl.create(:stolenRecord, receive_notifications: false)
      stolenRecord.bike.update_attribute :stolen, true
      customer_contact = FactoryGirl.create(:customer_contact, bike: stolenRecord.bike)
      ActionMailer::Base.deliveries = []
      EmailStolenBikeAlertWorker.new.perform(customer_contact.id)
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
