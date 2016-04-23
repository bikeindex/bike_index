require 'spec_helper'

describe 'Swagger API V2 docs' do
  describe 'all the paths' do
    it 'responds with swagger for all the apis' do
      get 'api/v2/swagger_doc'
      result = JSON(response.body)
      expect(response.code).to eq('200')
      result['apis'].each do |api|
        get "api/v2/swagger_doc#{api['path']}"
        expect(response.code).to eq('200')
      end
    end

    it 'redirects to documentation on API call' do
      get 'api'
      expect(response).to redirect_to('/documentation')
    end
  end
end
