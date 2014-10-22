require 'spec_helper'

describe Api::V1::ComponentTypesController do
  describe :index do
    it "loads the request" do
      FactoryGirl.create(:ctype)
      get :index, format: :json
      response.code.should eq('200')
    end
  end   
end
