require 'spec_helper'

describe Admin::FlavorTextsController do
  describe 'destroy' do
    before do
      text = FlavorText.create(message: 'lulz')
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      delete :destroy, id: text.id
    end
    it { is_expected.to redirect_to(:admin_root) }
    it { is_expected.to set_flash }
  end

  describe 'update' do
    describe 'success' do
      before do
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        post :create, flavor_text: { message: 'lulz' }
      end
      it { is_expected.to redirect_to(:admin_root) }
      it { is_expected.to set_flash }
    end
  end
end
