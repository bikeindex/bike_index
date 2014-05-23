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
      # response.body.should include("user_present" => true)
    end
  end

  describe :request_serial_update do 
    it "should create a new serial request mail" do 
      o = FactoryGirl.create(:ownership)
      user = o.creator
      bike = o.bike
      serial_request = { serial_update_bike_id: bike.id,
        serial_update_email: user.email,
        serial_update_serial: 'some new serial',
        serial_update_reason: 'Some reason'
      }
      set_current_user(user)
      lambda {
        put :request_serial_update, serial_request, format: :json
      }.should change(Feedback, :count).by(1)
      response.code.should eq('200')
    end
    
    xit "shouldn't create a new serial request mailer if a user isn't present" do 
      bike = FactoryGirl.create(:bike)
      message = { serial_update_bike_id: bike.id, serial_update_email: 'someemail@stuff.com', serial_update_serial: 'some update', serial_update_reason: 'Some reason' }
      # pp message
      post :request_serial_update, message
      pp response.body
      response.code.should eq('403')
    end

    xit "shouldn't create a new serial request mailer if a user isn't present" do 
      o = FactoryGirl.create(:ownership)
      bike = o.bike
      user = FactoryGirl.create(:user)
      set_current_user(user)
      params = { serial_update_bike_id: bike.id, serial_update_email: user.email, serial_update_serial: 'some update', serial_update_reason: 'Some reason' }
      post :request_serial_update, params
      pp response 
      response.code.should eq('403')
    end
  end

end
