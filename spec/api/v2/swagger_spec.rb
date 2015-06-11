require 'spec_helper'

describe 'Swagger API V2 docs' do
  describe 'all the paths' do 
    it "responds with swagger for all the apis" do
      get 'api/v2/swagger_doc'
      result = JSON(response.body)
      response.code.should eq('200')
      result['apis'].each do |api|
        get "api/v2/swagger_doc#{api['path']}"
        response.code.should eq('200')
      end
    end

    it "redirects to documentation on API call" do
      get 'api'
      response.should redirect_to("/documentation")
    end
  end
end