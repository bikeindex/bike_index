require 'spec_helper'

describe Admin::RecoveriesController do
  describe 'index' do
    it 'renders' do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
      expect(response).to be_success
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
    end
  end
end
