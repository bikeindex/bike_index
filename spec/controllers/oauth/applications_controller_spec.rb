require 'spec_helper'

describe Oauth::ApplicationsController do
  
  describe :index do 
    before do 
      create_v2_access_id
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :index
    end
    # it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :create do 
    it "should create an application and add the v2 accessor to it" do 
      create_v2_access_id
      user = FactoryGirl.create(:user)
      set_current_user(user)
      app_attrs = {
        name: "Some app",
        redirect_uri: "urn:ietf:wg:oauth:2.0:oob"
      }
      post :create, application: app_attrs
      app = user.oauth_applications.first
      app.name.should eq(app_attrs[:name])
      app.access_tokens.count.should eq(1)
      v2_accessor = app.access_tokens.last
      # pp v2_accessor
      v2_accessor.resource_owner_id.should eq(ENV['V2_ACCESSOR_ID'].to_i)
    end
  end

end
