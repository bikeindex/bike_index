require 'spec_helper'

describe Admin::DashboardController do
  describe :index do 
    before do 
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :index do 
    it "fails for non logged in" do 
      get :index
      response.code.should eq('302')
      response.should redirect_to(root_url)
    end

    it "fails for non admins" do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :index
      response.code.should eq('302')
      response.should redirect_to(user_home_url)
    end

    it "fails for content admins" do 
      user = FactoryGirl.create(:user, is_content_admin: true)
      set_current_user(user)
      get :index
      response.code.should eq('302')
      response.should redirect_to(admin_news_index_url)
    end
  end

  describe :invitations do 
    before do 
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      b_param = BParam.create(creator_id: user.id)
      get :invitations
    end
    it { should respond_with(:success) }
    it { should render_template(:invitations) }
  end

  describe :maintenance do 
    before do 
      FactoryGirl.create(:manufacturer, name: "other")
      FactoryGirl.create(:ctype, name: "other")
      FactoryGirl.create(:handlebar_type, slug: "other")
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      b_param = BParam.create(creator_id: user.id)
      get :maintenance
    end
    it { should respond_with(:success) }
    it { should render_template(:maintenance) }
  end
  
end
