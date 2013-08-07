require 'spec_helper'
describe CustomerMailer do

  before :each do
    @user = FactoryGirl.create(:user)
  end

  describe :welcome_email do
    before :each do
      @mail = CustomerMailer.welcome_email(@user)
    end

    it "renders email" do
      @mail.subject.should eq("Welcome to the Bike Index!")
    end
  end

  describe :confirmation_email do
    before :each do
      @mail = CustomerMailer.confirmation_email(@user)
    end

    it "renders email" do
      @mail.subject.should eq("Welcome to the Bike Index!")
    end
  end

  describe :password_reset_email do
    before :each do
      @mail = CustomerMailer.password_reset_email(@user)
    end

    it "renders email" do
      @mail.subject.should eq("Instructions to reset your password")
      @mail.body.encoded.should match("reset")
    end
  end

  describe :ownership_invitation_email do
    before :each do
      @ownership = FactoryGirl.create(:ownership)
      @mail = CustomerMailer.ownership_invitation_email(@ownership)
    end

    it "should render email" do
      @mail.subject.should eq("Claim your bike on BikeIndex.org!")
    end
  end

  describe :organization_invitation_email do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @organization_invitation = FactoryGirl.create(:organization_invitation, organization: @organization)
      @mail = CustomerMailer.organization_invitation_email(@organization_invitation)
    end

    it "should render email" do
      @mail.subject.should eq("Join #{@organization.name} on the Bike Index")
    end
  end

  describe :bike_token_invitation_email do
    before :each do
      @bike_token_invitation = FactoryGirl.create(:bike_token_invitation, message: "Test Message", subject: "Test subject")
      @mail = CustomerMailer.bike_token_invitation_email(@bike_token_invitation)
    end

    it "should render email" do
      @mail.subject.should eq("Test subject")
      @mail.body.encoded.should match(@bike_token_invitation.message)
    end
  end

  describe :stolen_notification_email do 
    before :each do
      @stolen_notification = FactoryGirl.create(:stolen_notification, message: "Test Message", subject: "Test subject")
      @mail = CustomerMailer.stolen_notification_email(@stolen_notification)
    end

    it "should render email" do
      @mail.subject.should eq("Test subject")
      @mail.body.encoded.should match(@stolen_notification.message)
    end
  end

end
