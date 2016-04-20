require 'spec_helper'

describe Api::V1::ColorsController do
  describe 'index' do
    it 'loads the page' do
      FactoryGirl.create(:color)
      get :index, format: :json
      expect(response.code).to eq('200')
    end
  end   
end
