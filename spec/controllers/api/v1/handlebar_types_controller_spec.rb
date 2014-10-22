require 'spec_helper'

describe Api::V1::HandlebarTypesController do
  
  describe :index do
    it "loads the page" do
      FactoryGirl.create(:handlebar_type)
      get :index, format: :json
      response.code.should eq('200')
    end
  end   
end
