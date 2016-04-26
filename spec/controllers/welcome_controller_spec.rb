require 'spec_helper'

describe WelcomeController do
  describe 'index' do
    context 'legacy' do
      it 'renders' do
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template('index')
        expect(response).to render_with_layout('application_updated')
        expect(flash).to_not be_present
      end
    end
    context 'revised' do
      it 'renders' do
        allow(controller).to receive(:revised_layout_enabled?) { true }
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template('index')
        expect(response).to render_with_layout('application_revised')
        expect(flash).to_not be_present
      end
    end
  end

  describe 'goodbye' do
    context 'legacy' do
      it 'renders' do
        get :goodbye
        expect(response.status).to eq(200)
        expect(response).to render_template('goodbye')
        expect(response).to render_with_layout('application')
        expect(flash).to_not be_present
      end
    end
  end

  describe 'user_home' do
    context 'user not present' do
      it 'redirects' do
        get :user_home
        expect(response.status).to eq(200)
        expect(response).to redirect_to(new_user_url)
        expect(flash).to be_present
      end
    end

    context 'when user is present' do
      it 'renders and user things are assigned' do
        user = FactoryGirl.create(:user)
        ownership = FactoryGirl.create(:ownership, user_id: user.id, current: true)
        lock = FactoryGirl.create(:lock, user: user)
        set_current_user(user)
        get :user_home
        expect(assigns(:bikes).first).to eq(ownership.bike)
        expect(assigns(:locks).first).to eq(lock)
      end
    end
  end
end
