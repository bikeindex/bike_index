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
    context 'developer user' do
      it 'renders' do
        user = FactoryGirl.create(:developer)
        set_current_user(user)
        FactoryGirl.create(:organization, name: 'Example organization') # Required because I'm an idiot
        get :api_v1
        expect(response.code).to eq('200')
        expect(response).to render_template('api_v1')
        expect(flash).to_not be_present
      end
    end
    context 'user' do
      it 'redirects to home, message API deprecated' do
        user = FactoryGirl.create(:user)
        set_current_user(user)
        get :api_v1
        expect(response).to redirect_to documentation_index_path
        expect(flash[:notice]).to match 'deprecated'
      end
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
