require 'spec_helper'

describe Api::V1::CycleTypesController do
  describe 'index' do
    it 'loads the request' do
      get :index, format: :json
      expect(response.code).to eq('200')
    end
  end
end
