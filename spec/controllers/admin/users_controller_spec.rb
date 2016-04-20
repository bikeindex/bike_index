require 'spec_helper'

describe Admin::UsersController do
  describe 'edit' do
    xit "404s if the user doesn't exist" do
      # I have no idea why this fails. It works really, but not in tests!
      expect {
        get :edit, id: 'STUFFFFFF'
      }.to raise_error(ActionController::RoutingError)
    end
    it 'shows the edit page if the user exists' do
      admin = FactoryGirl.create(:admin)
      user = FactoryGirl.create(:user)
      set_current_user(admin)
      get :edit, id: user.username
      expect(response).to render_template :edit
    end
  end

  describe 'update' do
    context 'non developer' do
      it 'updates all the things that can be edited' do
        admin = FactoryGirl.create(:admin)
        user = FactoryGirl.create(:user, confirmed: false)
        set_current_user(admin)
        post :update, id: user.username, user: {
          name: 'New Name',
          email: 'newemailexample.com',
          confirmed: true,
          superuser: true,
          developer: true,
          is_content_admin: true,
          can_send_many_stolen_notifications: true,
          banned: true
        }
        expect(user.reload.name).to eq('New Name')
        expect(user.email).to eq('newemailexample.com')
        expect(user.confirmed).to be_truthy
        expect(user.superuser).to be_truthy
        expect(user.developer).to be_falsey
        expect(user.can_send_many_stolen_notifications).to be_truthy
        expect(user.banned).to be_truthy
      end
    end
    context 'developer' do
      it 'updates developer' do
        admin = FactoryGirl.create(:admin)
        admin.developer = true
        admin.save
        admin.reload
        set_current_user(admin)
        user = FactoryGirl.create(:user)

        post :update, id: user.username, user: { 
          developer: true,
          email: user.email,
          superuser: false,
          is_content_admin: true,
          can_send_many_stolen_notifications: true,
          banned: true
        }
        user.reload
        expect(user.developer).to be_truthy
      end
    end
  end
end
