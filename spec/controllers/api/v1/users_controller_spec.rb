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

end
