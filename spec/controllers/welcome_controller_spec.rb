require 'spec_helper'

describe WelcomeController do
  describe 'index' do
    before do
      get :index
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:index) }
    it { is_expected.not_to set_the_flash }
  end

  describe 'goodbye' do
    before do
      get :goodbye
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:goodbye) }
  end

  describe 'user_home' do
    describe "user not present" do
      before do
        get :user_home
      end
      it { is_expected.to respond_with(:redirect) }
      it { is_expected.to redirect_to(new_user_url) }
      it { is_expected.not_to set_the_flash }
    end

    describe "when user is present" do
      before do
        user = FactoryGirl.create(:user)
        FactoryGirl.create(:ownership, user_id: user.id, current: true)
        set_current_user(user)
        get :user_home
      end

      it { is_expected.not_to set_the_flash }
      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:user_home) }
    end

    describe "user things should be assigned" do
      it "sends the bikes and the locks" do
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
