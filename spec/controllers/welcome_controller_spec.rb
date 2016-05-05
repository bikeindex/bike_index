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
    context 'revised' do
      it 'renders with revised_layout' do
        allow(controller).to receive(:revised_layout_enabled?) { true }
        get :goodbye
        expect(response.status).to eq(200)
        expect(response).to render_template('goodbye')
        expect(response).to render_with_layout('application_revised')
        expect(flash).to_not be_present
      end
    end
  end

  describe 'user_home' do
    context 'user not present' do
      it 'redirects' do
        get :user_home
        expect(response).to redirect_to(new_user_url)
      end
    end

    context 'when user is present' do
      let(:user) { FactoryGirl.create(:user) }
      let(:ownership) { FactoryGirl.create(:ownership, user_id: user.id, current: true) }
      let(:bike) { ownership.bike }
      let(:bike_2) { FactoryGirl.create(:bike) }
      let(:lock) { FactoryGirl.create(:lock, user: user) }
      before do
        allow_any_instance_of(User).to receive(:bikes) { [bike, bike_2] }
        allow_any_instance_of(User).to receive(:locks) { [lock] }
        set_current_user(user)
      end
      context 'legacy' do
        it 'renders and user things are assigned' do
          get :user_home
          expect(response.status).to eq(200)
          expect(assigns(:per_page).to_s).to eq '20'
          expect(response).to render_template('user_home')
          expect(response).to render_with_layout('no_container')
          expect(assigns(:bikes).first).to eq(bike)
          expect(assigns(:locks).first).to eq(lock)
        end
      end
      context 'revised_layout' do
        it 'renders and user things are assigned' do
          allow(controller).to receive(:revised_layout_enabled?) { true }
          get :user_home, per_page: 1
          expect(response.status).to eq(200)
          expect(response).to render_template('revised_user_home')
          expect(response).to render_with_layout('application_revised')
          expect(assigns(:bikes).count).to eq 1
          expect(assigns(:per_page).to_s).to eq '1'
          expect(assigns(:bikes).first).to eq(bike)
          expect(assigns(:locks).first).to eq(lock)
        end
      end
    end
  end
end
