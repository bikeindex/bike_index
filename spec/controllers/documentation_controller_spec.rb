require 'spec_helper'

describe DocumentationController do
  describe 'index' do
    it 'redirects to current api documentation' do
      get :index
      expect(response).to redirect_to('/documentation/api_v2')
      expect(flash).to_not be_present
    end
  end

  describe 'api_v1' do
    it 'renders' do
      FactoryGirl.create(:organization, name: 'Example organization') # Required because I'm an idiot
      get :api_v1
      expect(response.code).to eq('200')
      expect(response).to render_template('api_v1')
      expect(flash).to_not be_present
    end
  end

  describe 'api_v2' do
    it 'renders' do
      get :api_v2
      expect(response.code).to eq('200')
      expect(response).to render_template('api_v2')
      expect(flash).to_not be_present
    end
  end
end
