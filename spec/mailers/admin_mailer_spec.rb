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

  describe 'special_feedback_notification_email' do
    before :each do
      @bike = FactoryGirl.create(:bike)
      @feedback = FactoryGirl.create(:feedback, feedback_hash: {bike_id: @bike.id})
    end
    it 'sends a delete request email' do
      @feedback.update_attributes(feedback_type: 'bike_delete_request')
      mail = AdminMailer.feedback_notification_email(@feedback)
      mail.subject.should eq("New Feedback Submitted")
      mail.to.should eq(["contact@bikeindex.org"])
      mail.from.should eq([@feedback.email])
    end
    it 'sends a recovery email' do
      @feedback.update_attributes(feedback_type: 'bike_recovery')
      mail = AdminMailer.feedback_notification_email(@feedback)
      mail.subject.should eq("New Feedback Submitted")
      mail.to.should eq(["contact@bikeindex.org", "bryan@bikeindex.org"])
      mail.from.should eq([@feedback.email])
    end
    it 'sends a stolen_information email' do
      @feedback.update_attributes(feedback_type: 'stolen_information')
      mail = AdminMailer.feedback_notification_email(@feedback)
      mail.to.should eq(["bryan@bikeindex.org"])
    end
    it 'sends a serial update email' do
      @feedback.update_attributes(feedback_type: 'serial_update_request')
      mail = AdminMailer.feedback_notification_email(@feedback)
      mail.subject.should eq("New Feedback Submitted")
      mail.to.should eq(["contact@bikeindex.org"])
      mail.from.should eq([@feedback.email])
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

    it "renders email" do
      @mail.subject[/blocked/i].present?.should be_true
      @mail.body.encoded.should match(@stolen_notification.message)
    end
  end
  
end
