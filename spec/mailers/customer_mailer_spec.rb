require 'spec_helper'
describe CustomerMailer do
  describe 'including_snippet' do
    it 'includes the snippet' do
      @ownership = FactoryGirl.create(:ownership)
      mail_snippet = MailSnippet.new(body: '<h1>LOLS</h1>')
      expect(MailSnippet).to receive(:matching_opts).and_return(mail_snippet)
      @mail = CustomerMailer.ownership_invitation_email(@ownership)
      expect(@mail.body.encoded).to match(mail_snippet.body)
    end
  end

  describe 'welcome_email' do
    before :each do
      @user = FactoryGirl.create(:user)
      @mail = CustomerMailer.welcome_email(@user)
    end

    it 'renders email' do
      expect(@mail.subject).to eq('Welcome to the Bike Index!')
    end
  end

  describe 'confirmation_email' do
    before :each do
      @user = FactoryGirl.create(:user)
      @mail = CustomerMailer.confirmation_email(@user)
    end

    it 'renders email' do
      expect(@mail.subject).to eq('Welcome to the Bike Index!')
    end
  end

  describe 'password_reset_email' do
    before :each do
      @user = FactoryGirl.create(:user)
      @mail = CustomerMailer.password_reset_email(@user)
    end

    it 'renders email' do
      expect(@mail.subject).to eq('Instructions to reset your password')
      expect(@mail.body.encoded).to match('reset')
    end
  end

  describe 'ownership_invitation_email' do
    it 'renders email' do
      @ownership = FactoryGirl.create(:ownership)
      @mail = CustomerMailer.ownership_invitation_email(@ownership)
      expect(@mail.subject).to eq('Claim your bike on BikeIndex.org!')
    end
  end

  describe 'organization_invitation_email' do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @organization_invitation = FactoryGirl.create(:organization_invitation, organization: @organization)
      @mail = CustomerMailer.organization_invitation_email(@organization_invitation)
    end

    it 'renders email' do
      expect(@mail.subject).to eq("Join #{@organization.name} on the Bike Index")
    end
  end

  describe 'stolen_notification_email' do
    it 'renders email and update sent_dates' do
      stolen_notification = FactoryGirl.create(:stolen_notification, message: 'Test Message')
      mail = CustomerMailer.stolen_notification_email(stolen_notification)
      expect(mail.subject).to eq(stolen_notification.default_subject)
      expect(mail.from.count).to eq(1)
      expect(mail.from.first).to eq('bryan@bikeindex.org')
      expect(mail.body.encoded).to match(stolen_notification.message)
      expect(stolen_notification.send_dates[0]).to eq(stolen_notification.updated_at.to_i)
      CustomerMailer.stolen_notification_email(stolen_notification)
      expect(stolen_notification.send_dates[1]).to be > stolen_notification.updated_at.to_i - 2
    end
  end

  describe 'admin_contact_stolen_email' do
    it 'renders email' do
      stolen_record = FactoryGirl.create(:stolen_record)
      user = FactoryGirl.create(:admin)
      customer_contact = CustomerContact.new(user_email: stolen_record.bike.owner_email,
                                             creator_email: user.email,
                                             body: 'some message',
                                             contact_type: 'stolen_contact',
                                             bike_id: stolen_record.bike.id,
                                             title: 'some title')
      customer_contact.save
      mail = CustomerMailer.admin_contact_stolen_email(customer_contact)
      expect(mail.subject).to eq('some title')
      expect(mail.body.encoded).to match('some message')
    end
  end
  describe 'stolen_bike_alert_email' do
    it 'renders email' do
      stolen_record = FactoryGirl.create(:stolen_record)
      notification_hash = {
        notification_type: 'stolen_twitter_alerter',
        bike_id: stolen_record.bike.id,
        tweet_id: 69,
        tweet_string: 'STOLEN - something special',
        tweet_account_screen_name: 'bikeindex',
        tweet_account_name: 'Bike Index',
        tweet_account_image: 'https://pbs.twimg.com/profile_images/3384343656/33893b31d39d69fb4b85912489c497b0_bigger.png',
        location: 'Everywhere',
        retweet_screen_names: %w(someother_screename and_another)
      }
      customer_contact = FactoryGirl.create(:customer_contact, info_hash: notification_hash)
      mail = CustomerMailer.stolen_bike_alert_email(customer_contact)
    end
  end
end
