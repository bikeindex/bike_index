require "spec_helper"

describe Api::V1::UsersController do

  describe :current do 

    it "should return user_present = false if there is no user present" do
      get :current, format: :json
      response.code.should eq('200')
    end

    it "should return user_present if a user is present" do 
      u = FactoryGirl.create(:user)
      set_current_user(u)
      get :current, format: :json
      response.code.should eq('200')
      pp response.body
      JSON.parse(response.body).should include("user_present" => true)
    end
  end

  describe :send_request do 
    it "should create a new serial update mail and update the serial" do 
      o = FactoryGirl.create(:ownership)
      user = o.creator
      bike = o.bike
      serial_request = { 
        request_type: 'serial_update_request',
        user_id: user.id,
        request_bike_id: bike.id,
        request_reason: 'Some reason',
        serial_update_serial: 'some new serial'
      }
      set_current_user(user)
      ActionMailer::Base.deliveries = []
      SerialNormalizer.any_instance.should_receive(:save_segments)
      Resque.should_receive(:enqueue)
      post :send_request, serial_request
      response.code.should eq('200')
      FeedbackNotificationEmailJob.perform(Feedback.where(feedback_type: 'serial_update_request').first.id)
      ActionMailer::Base.deliveries.should_not be_empty
      bike.reload.serial_number.should eq('some new serial')
    end

    it "should create a new bike delete request mail" do 
      o = FactoryGirl.create(:ownership)
      user = o.creator
      bike = o.bike
      delete_request = { 
        request_type: 'bike_delete_request',
        user_id: user.id,
        request_bike_id: bike.id,
        request_reason: 'Some reason',
      }
      set_current_user(user)
      Resque.should_receive(:enqueue)
      post :send_request, delete_request
      response.code.should eq('200')
    end


    it "should create a new recovery request mail" do 
      Sidekiq::Testing.inline! do 
        o = FactoryGirl.create(:ownership)
        user = o.creator
        bike = o.bike
        stolen_record = FactoryGirl.create(:stolen_record, bike: bike)
        bike.update_attribute :stolen, true
        recovery_request = { 
          request_type: 'bike_recovery',
          user_id: user.id,
          request_bike_id: bike.id,
          request_reason: 'Some reason',
          index_helped_recovery: 'true',
          can_share_recovery: 'true'
        }
        set_current_user(user)
        Resque.should_receive(:enqueue)
        post :send_request, recovery_request.as_json
        response.code.should eq('200')
        # ALSO MAKE SURE IT RECOVERY NOTIFIES
        bike.current_stolen_record.date_recovered.should be_present
        bike.current_stolen_record.recovery_posted.should be_false
        bike.current_stolen_record.index_helped_recovery.should be_true
        bike.current_stolen_record.can_share_recovery.should be_true
      end
    end
      
    it "shouldn't create a new serial request mailer if a user isn't present" do 
      bike = FactoryGirl.create(:bike)
      message = { request_bike_id: bike.id, serial_update_serial: 'some update', request_reason: 'Some reason' }
      # pp message
      post :send_request, message, format: :json
      response.code.should eq('403')
    end

    it "shouldn't create a new serial request mailer if wrong user user is present" do 
      o = FactoryGirl.create(:ownership)
      bike = o.bike
      user = FactoryGirl.create(:user)
      set_current_user(user)
      params = { request_bike_id: bike.id, serial_update_serial: 'some update', request_reason: 'Some reason' }
      post :send_request, params
      # pp response 
      response.code.should eq('403')
    end
  end

end
