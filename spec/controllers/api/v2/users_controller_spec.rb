require 'spec_helper'

describe Api::V2::UsersController do  
  # We are using the manufacturers controller to test
  # general API v2 functionality

  # describe :index do
  #   it "loads the request" do
  #     m = FactoryGirl.create(:manufacturer)
  #     get :index, format: :json
  #     response.code.should eq('200')
  #     JSON.parse(response.body)['manufacturers'][0]['name'].should eq(m.name)
  #     response.headers['Access-Control-Allow-Origin'].should eq('*')
  #     response.headers['Access-Control-Allow-Methods'].should eq('POST, PUT, GET, OPTIONS')
  #     response.headers['Access-Control-Request-Method'].should eq('*')
  #     response.headers['Access-Control-Allow-Headers'].should eq('Origin, X-Requested-With, Content-Type, Accept, Authorization')
  #     response.headers['Access-Control-Max-Age'].should eq("1728000")
  #   end
  # end

  # describe :show do
  #   it "shows the manufacturer" do 
  #     m = FactoryGirl.create(:manufacturer)
  #     get :show, id: m.name, format: :json
  #     response.code.should eq("200")
  #     JSON.parse(response.body)['manufacturer']['name'].should eq(m.name)
  #   end

  #   it "fails correctly when not found request" do
  #     lambda {
  #       get :show, id: 'somemnfg', format: :json
  #     }.should raise_error(ActiveRecord::RecordNotFound)
  #     # response.response_code.should == 404
  #     JSON.parse(response.body)['404'].should be_present
  #   end

  # end    
end
