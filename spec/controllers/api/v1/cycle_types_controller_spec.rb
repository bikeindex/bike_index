require 'spec_helper'

describe Api::V1::CycleTypesController do  
  describe :index do
    it "should load the request" do
      FactoryGirl.create(:cycle_type)
      get :index, format: :json
      response.code.should eq('200')
    end
  end   
end
