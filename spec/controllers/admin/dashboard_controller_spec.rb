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

  describe :tsvs do 
    it "renders and assigns tsvs" do 
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      t = Time.now
      FileCacheMaintainer.reset_file_info('current_stolen_bikes.tsv', t)
      tsvs = [{filename: 'current_stolen_bikes.tsv', updated_at: "#{t.to_i}", description: 'Approved Stolen bikes'}]
      blacklist = ['1010101', '2', '4', '6']
      FileCacheMaintainer.reset_blacklist_ids(blacklist)
      get :tsvs
      response.code.should eq('200')
      # assigns(:tsvs).should eq(tsvs)
      assigns(:blacklist).include?('2').should be_true
    end
  end

  describe :update_tsv_blacklist do 
    it "renders and updates" do 
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      ids = "\n1\n2\n69\n200\n22222\n\n\n"
      put :update_tsv_blacklist, {blacklist: ids}
      expect(FileCacheMaintainer.blacklist).to eq([1, 2, 69, 200, 22222].map(&:to_s))
    end
  end
  
end
