require 'spec_helper'

describe Api::V1::WheelSizesController do
  
  describe :index do
    it "should load the page" do
      FactoryGirl.create(:wheel_size)
      get :index, format: :json
      response.code.should eq('200')
    end
  end   
end
