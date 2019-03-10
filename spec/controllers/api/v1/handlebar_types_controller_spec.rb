require 'spec_helper'

describe Api::V1::HandlebarTypesController do
  describe 'index' do
    it 'loads the page' do
      get :index, format: :json
      expect(response.code).to eq('200')
    end
  end
end
