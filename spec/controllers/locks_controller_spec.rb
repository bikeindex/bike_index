require 'spec_helper'

describe LocksController do

  describe :index do
    before do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { assigns(:locks).should be_decorated }
  end

  describe :show do 
    before do
      user = FactoryGirl.create(:user)
      set_current_user(user)
      lock = FactoryGirl.create(:lock, user: user)
      get :show, id: lock.id
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
    it { assigns(:lock).should be_decorated }
  end

  describe :new do 
    before do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :new
    end
    it { should respond_with(:success) }
    it { should render_template(:new) }
  end

  describe :edit do 
    describe "not correct lock owner" do 
      before do 
        user = FactoryGirl.create(:user)
        set_current_user(user)
        lock = FactoryGirl.create(:lock)
        get :show, id: lock.id
      end
      it { should redirect_to(:user_home) }
    end
    describe "correct lock owner" do 
      before do 
        user = FactoryGirl.create(:user)
        set_current_user(user)
        lock = FactoryGirl.create(:lock, user: user)
        get :edit, id: lock.id
      end
      it { should respond_with(:success) }
      it { should render_template(:edit) }
    end
  end

end
