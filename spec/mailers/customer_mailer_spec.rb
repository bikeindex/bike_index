require 'spec_helper'
describe CustomerMailer do

  describe :including_snippet do 
    it "includes the snippet" do 
      @ownership = FactoryGirl.create(:ownership)
      mail_snippet = MailSnippet.new(body: "<h1>LOLS</h1>")
      MailSnippet.should_receive(:matching_opts).and_return(mail_snippet)
      @mail = CustomerMailer.ownership_invitation_email(@ownership)
      @mail.body.encoded.should match(mail_snippet.body)
    end
  end

  describe :confirmation_email do
    before :each do
      @user = FactoryGirl.create(:user)
      @mail = CustomerMailer.confirmation_email(@user)
    end

    it "renders email" do
      @mail.subject.should eq("Welcome to the Bike Index!")
    end
  end

  describe :password_reset_email do
    before :each do
      @user = FactoryGirl.create(:user)
      @mail = CustomerMailer.password_reset_email(@user)
    end

    it "renders email" do
      @mail.subject.should eq("Instructions to reset your password")
      @mail.body.encoded.should match("reset")
    end
  end

  describe :ownership_invitation_email do
    it "renders email" do
      @ownership = FactoryGirl.create(:ownership)
      @mail = CustomerMailer.ownership_invitation_email(@ownership)
      @mail.subject.should eq("Claim your bike on BikeIndex.org!")
    end
  end

  describe :organization_invitation_email do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @organization_invitation = FactoryGirl.create(:organization_invitation, organization: @organization)
      @mail = CustomerMailer.organization_invitation_email(@organization_invitation)
    end

    it "renders email" do
      @mail.subject.should eq("Join #{@organization.name} on the Bike Index")
    end
  end

  describe :bike_token_invitation_email do
    before :each do
      @bike_token_invitation = FactoryGirl.create(:bike_token_invitation, message: "Test Message", subject: "Test subject")
      @mail = CustomerMailer.bike_token_invitation_email(@bike_token_invitation)
    end

    it "renders email" do
      @mail.subject.should eq("Test subject")
      @mail.body.encoded.should match(@bike_token_invitation.message)
    end
  end

  describe :stolen_notification_email do 
    it "renders email and update sent_dates" do
      stolen_notification = FactoryGirl.create(:stolen_notification, message: "Test Message", subject: "Test subject")
      mail = CustomerMailer.stolen_notification_email(stolen_notification)
      mail.subject.should eq("Test subject")
      mail.body.encoded.should match(stolen_notification.message)
      stolen_notification.send_dates[0].should eq(stolen_notification.updated_at.to_i)
      CustomerMailer.stolen_notification_email(stolen_notification)
      stolen_notification.send_dates[1].should be > stolen_notification.updated_at.to_i - 2
    end
  end

  describe :admin_contact_stolen_email do
    it "renders email" do
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
      mail.subject.should eq("some title")
      mail.body.encoded.should match('some message')
    end
  end
  describe :stolen_bike_alert_email do
    it "renders email" do
      stolen_record = FactoryGirl.create(:stolen_record)
      notification_hash = {
        notification_type: 'stolen_twitter_alerter',
        bike_id: stolen_record.bike.id,
        tweet_id: 69,
        tweet_string: "STOLEN - something special",
        tweet_account_screen_name: "bikeindex",
        tweet_account_name: "Bike Index",
        tweet_account_image: "https://pbs.twimg.com/profile_images/3384343656/33893b31d39d69fb4b85912489c497b0_bigger.png",
        location: 'Everywhere',
        retweet_screen_names: ['someother_screename', 'and_another']
      }
      customer_contact = FactoryGirl.create(:customer_contact, info_hash: notification_hash)
      mail = CustomerMailer.stolen_bike_alert_email(customer_contact)
    end
  end

end
