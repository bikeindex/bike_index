require 'spec_helper'

describe Admin::DashboardController do
  describe :index do 
    before do 
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :invitations do 
    before do 
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      b_param = BParam.create(creator_id: user.id)
      get :invitations
    end
    it { should respond_with(:success) }
    it { should render_template(:invitations) }
  end

  describe :maintenance do 
    before do 
      FactoryGirl.create(:manufacturer, name: "Other")
      FactoryGirl.create(:ctype, name: "Other")
      FactoryGirl.create(:handlebar_type, slug: "other")
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      b_param = BParam.create(creator_id: user.id)
      get :maintenance
    end
    it { should respond_with(:success) }
    it { should render_template(:maintenance) }
  end
  
end
