require 'spec_helper'

describe Admin::FlavorTextsController do
  describe 'destroy' do
    it 'destroys' do
      text = FlavorText.create(message: 'lulz')
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      expect do
        delete :destroy, id: text.id
      end.to change(FlavorText, :count).by(-1)
    end
  end

  describe 'update' do
    describe 'success' do
      it 'updates' do
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        post :create, flavor_text: { message: 'lulz' }
        expect(response).to redirect_to(:admin_root)
        expect(flash).to be_present
        expect(FlavorText.last.message).to eq 'lulz'
      end
    end
  end
end
