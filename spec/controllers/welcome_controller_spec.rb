require 'spec_helper'

describe WelcomeController do
  describe 'index' do
    it 'renders' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template('index')
      expect(response).to render_with_layout('application_revised')
      expect(flash).to_not be_present
    end
  end

  describe 'bike_creation_graph' do
    it 'renders embed without xframe block' do
      get :bike_creation_graph
      expect(response.code).to eq('200')
      expect(response.headers['X-Frame-Options']).not_to be_present
    end
  end

  describe 'goodbye' do
    it 'renders' do
      get :goodbye
      expect(response.status).to eq(200)
      expect(response).to render_template('goodbye')
      expect(response).to render_with_layout('application_revised')
      expect(flash).to_not be_present
    end
  end

  describe 'choose registration' do
    context 'user not present' do
      it 'redirects' do
        get :choose_registration
        expect(response).to redirect_to(new_user_url)
      end
    end
    context 'user present' do
      it 'renders' do
        user = FactoryGirl.create(:user)
        set_current_user(user)
        get :choose_registration
        expect(response.status).to eq(200)
        expect(response).to render_template('choose_registration')
        expect(response).to render_with_layout('application_revised')
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
      context 'without anything' do
        it 'renders' do
          set_current_user(user)
          get :user_home
          expect(response.status).to eq(200)
          expect(response).to render_template('user_home')
          expect(response).to render_with_layout('application_revised')
        end
      end
      context 'with stuff' do
        let(:ownership) { FactoryGirl.create(:ownership, user_id: user.id, current: true) }
        let(:bike) { ownership.bike }
        let(:bike_2) { FactoryGirl.create(:bike) }
        let(:lock) { FactoryGirl.create(:lock, user: user) }
        before do
          allow_any_instance_of(User).to receive(:bikes) { [bike, bike_2] }
          allow_any_instance_of(User).to receive(:locks) { [lock] }
          set_current_user(user)
        end
        it 'renders and user things are assigned' do
          get :user_home, per_page: 1
          expect(response.status).to eq(200)
          expect(response).to render_template('user_home')
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