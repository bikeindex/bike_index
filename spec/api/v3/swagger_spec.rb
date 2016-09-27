require 'spec_helper'

describe 'Swagger API V3 docs' do
  describe 'all the paths' do
    it 'responds with swagger for all the endpoints' do
      get '/api/v3/swagger_doc'
      result = JSON(response.body)
      expect(response.code).to eq('200')
      result['apis'].each do |api|
        get "/api/v3/swagger_doc#{api['path']}"
        expect(response.code).to eq('200')
      end
    end
  end
end
