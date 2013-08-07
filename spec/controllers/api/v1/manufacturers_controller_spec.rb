require 'spec_helper'

describe Api::V1::ManufacturersController do
  
  describe :index do
    it "should load the page" do
      FactoryGirl.create(:manufacturer)
      get :index, format: :json
      response.code.should eq('200')
    end
  end

  describe :show do
    it "should load the page" do
      @manufacturer = FactoryGirl.create(:manufacturer)
      get :show, id: @manufacturer.slug, format: :json
      response.code.should eq("200")
    end
  end
    
end
