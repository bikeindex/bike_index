require 'spec_helper'

describe Api::V1::WheelSizesController do
  describe 'index' do
    it 'loads the request' do
      FactoryGirl.create(:wheel_size)
      get :index, format: :json
      expect(response.code).to eq('200')
    end
  end
end
