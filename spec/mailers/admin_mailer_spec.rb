require 'spec_helper'

describe AdminMailer do

  describe :feedback_notification_email do
    before :each do
      @feedback = FactoryGirl.create(:feedback)
      @mail = AdminMailer.feedback_notification_email(@feedback)
    end
    it "renders email" do 
      @mail.subject.should eq("New Feedback Submitted")
      @mail.to.should eq(["contact@bikeindex.org"])
      @mail.from.should eq([@feedback.email])
    end
  end

  describe :no_admins_notification_email do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @mail = AdminMailer.no_admins_notification_email(@organization)
    end

    it "renders email" do
      @mail.to.should eq(['contact@bikeindex.org'])
      @mail.subject.should match("doesn't have any admins")
    end
  end

  describe :blocked_stolen_notification_email do 
    before :each do
      @stolen_notification = FactoryGirl.create(:stolen_notification, message: "Test Message", subject: "Test subject")
      @mail = AdminMailer.blocked_stolen_notification_email(@stolen_notification)
    end

    it "should render email" do
      @mail.subject[/blocked/i].present?.should be_true
      @mail.body.encoded.should match(@stolen_notification.message)
    end
  end
  
end