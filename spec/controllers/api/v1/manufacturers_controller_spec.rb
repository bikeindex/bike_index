require 'spec_helper'

describe Api::V1::ManufacturersController do
  
  describe :index do
    it "should load the page" do
      FactoryGirl.create(:manufacturer)
      get :index, format: :json
      response.code.should eq('200')
      response.headers['Access-Control-Allow-Origin'].should eq('*')
      response.headers['Access-Control-Allow-Methods'].should eq('POST, PUT, GET, OPTIONS')
      response.headers['Access-Control-Request-Method'].should eq('*')
      response.headers['Access-Control-Allow-Headers'].should eq('Origin, X-Requested-With, Content-Type, Accept, Authorization')
      response.headers['Access-Control-Max-Age'].should eq("1728000")
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
