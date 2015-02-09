require 'spec_helper'

describe Oauth::ApplicationsController do
  
  describe :index do 
    before do 
      user = FactoryGirl.create(:user)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :create do 
    it "creates an application" do 
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

  describe :edit do
    it "renders if owned by user" do 
      create_doorkeeper
      set_current_user(@user)
      get :edit, id: @application.id
      response.code.should eq('200')
      flash.should_not be_present
    end

    it "renders if superuser" do 
      create_doorkeeper
      admin = FactoryGirl.create(:admin)
      set_current_user(admin)
      get :edit, id: @application.id
      response.code.should eq('200')
      flash.should_not be_present
    end

    it "redirects if no user present" do 
      create_doorkeeper
      get :edit, id: @application.id
      response.should redirect_to new_session_url
      flash.should be_present
    end

    it "redirects if not owned by user" do 
      create_doorkeeper
      visitor = FactoryGirl.create(:user)
      set_current_user(visitor)
      get :edit, id: @application.id
      response.should redirect_to oauth_applications_url
      flash.should be_present
    end
  end

  describe :update do 
    it "renders if owned by user" do 
      create_doorkeeper
      set_current_user(@user)
      put :update, {id: @application.id, doorkeeper_application: {name: 'new thing'}}
      @application.reload
      @application.name.should eq('new thing')
    end

    it "doesn't update if not users" do 
      create_doorkeeper
      name = @application.name
      user = FactoryGirl.create(:user)
      set_current_user(user)
      put :update, {id: @application.id, doorkeeper_application: {name: 'new thing'}}
      @application.reload
      @application.name.should eq(name)
      response.should redirect_to oauth_applications_url
    end

  end



end
