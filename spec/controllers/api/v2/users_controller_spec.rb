require 'spec_helper'

describe Api::V2::UsersController do  
  # We are using the manufacturers controller to test
  # general API v2 functionality

  describe :current do
    xit "sends current user's api_v2_attributes_scoped" do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :current, format: :json
      response.response_code.should eq(200)
      response.body.should eq(user.api_v2_scoped.to_json)
    end

    it "sends correct error code when no user present" do
      get :current, format: :json
      response.response_code.should eq(401)
      response.body[/unauthorized/i].should be_present
    end
  end

  describe :access_scope do
    xit "sends current user's api_v2_attributes_scoped" do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :access_scope, format: :json
      response.response_code.should eq(200)
      response.body.match(/not through oauth/i).should be_present
    end

    it "responds with error if no user" do 
      get :access_scope, format: :json
      response.response_code.should eq(401)
      response.body[/unauthorized/i].should be_present
    end
  end
end
