require 'spec_helper'

describe Api::V1::FrameMaterialsController do
  
  describe :index do
    it "should load the page" do
      FactoryGirl.create(:frame_material)
      get :index, format: :json
      response.code.should eq('200')
    end
  end   
end
