require 'spec_helper'

describe Oauth::ApplicationsController do
  
  describe :index do 
    before do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :index
    end
    # it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :create do 
    it "should create an application" do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      app_attrs = {
        name: "Some app",
        redirect_uri: "urn:ietf:wg:oauth:2.0:oob"
      }
      post :create, {doorkeeper_application: app_attrs}
      app = user.oauth_applications.first
      app.name.should eq(app_attrs[:name])
    end
  end

end
