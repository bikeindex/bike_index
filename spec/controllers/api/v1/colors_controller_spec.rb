require 'spec_helper'

describe Api::V1::ColorsController do
  
  describe :index do
    it "loads the page" do
      FactoryGirl.create(:color)
      get :index, format: :json
      response.code.should eq('200')
    end
  end   
end
