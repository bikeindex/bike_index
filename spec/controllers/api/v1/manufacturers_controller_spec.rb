require 'spec_helper'

describe Api::V1::ManufacturersController do
  describe 'index' do
    it 'loads the request' do
      m = FactoryGirl.create(:manufacturer)
      get :index, format: :json
      expect(response.code).to eq('200')
      expect(JSON.parse(response.body)['manufacturers'].last['name']).to eq(m.name)
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(response.headers['Access-Control-Allow-Methods']).to eq('POST, PUT, GET, OPTIONS')
      expect(response.headers['Access-Control-Request-Method']).to eq('*')
      expect(response.headers['Access-Control-Allow-Headers']).to eq('Origin, X-Requested-With, Content-Type, Accept, Authorization')
      expect(response.headers['Access-Control-Max-Age']).to eq('1728000')
    end
  end
end
