require 'spec_helper'

describe StolenNotificationsController do
  before :each do
    @user = FactoryGirl.create(:user)
    @user2 = FactoryGirl.create(:user, name: "User2")
    @bike = FactoryGirl.create(:bike)
    @ownership = FactoryGirl.create(:ownership, {user: @user, bike: @bike, current: true})
  end
  describe :create do
    describe "success" do
      let(:stolen_notification_attributes) { 
        stolen_notification = FactoryGirl.attributes_for(:stolen_notification)
        stolen_notification[:bike_id] = @bike.id
        stolen_notification
      }
      
      it "creates a Stolen Notification record" do
        set_current_user(@user)
        lambda do
          post :create, stolen_notification: stolen_notification_attributes
        end.should change(StolenNotification, :count).by(1)
      end

      it "enqueues the stolen notification email job" do
        set_current_user(@user)
        expect {
          post :create, stolen_notification: stolen_notification_attributes
        }.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      end
    end

    describe "failure" do 
      let(:stolen_notification_attributes) { 
        stolen_notification = FactoryGirl.attributes_for(:stolen_notification, receiver: nil, bike: @bike)
        stolen_notification
      }

      it "does not work unless there is a user logged in" do
        lambda do
          post :create, stolen_notification: stolen_notification_attributes
        end.should_not change(StolenNotification, :count)
      end
    end
  end
end
