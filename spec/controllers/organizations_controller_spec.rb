require 'spec_helper'

describe OrganizationsController do

  describe :new do 
    describe "it should render the page without current user" do 
      before do 
        get :new
      end
      it { should respond_with(:success) }
      it { should render_template(:new) }
    end
  end

  describe :create do 
    it "should create org, membership, filter approved attrs & redirect to org with current_user" do 
      Organization.count.should eq(0)
      user = FactoryGirl.create(:user)
      set_current_user(user)
      org_attrs = {
        name: 'a new org',
        org_type: 'shop',
        api_access_approved: 'true',
        approved: 'true'
      }
      post :create, organization: org_attrs
      Organization.count.should eq(1)
      organization = Organization.where(name: 'a new org').first
      response.should redirect_to organization_url(organization)
      organization.approved.should be_false
      organization.api_access_approved.should be_false
      organization.auto_user_id.should eq(user.id)
      organization.memberships.count.should eq(1)
      organization.memberships.first.user_id.should eq(user.id)
    end
  end

  describe :update do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @user = FactoryGirl.create(:user)
      @membership = FactoryGirl.create(:membership, role: 'admin', user: @user, organization: @organization)
      session[:user_id] = @user.id
      User.any_instance.should_receive(:is_member_of?).and_return(true)
      User.any_instance.should_receive(:is_admin_of?).and_return(true)
    end

    xit "should update some fields" do
      # This is failing and I don't know why
      Organization.should_receive(:find_by_slug).at_least(:once).and_return(@organization)
      put :update, id: @organization.to_param, organization: { website: 'http://www.drseuss.org' }
      response.code.should eq('302')
      # pp assigns(:organization)
      @organization.reload.website.should eq('http://www.drseuss.org')
    end

    it "should send an admin notification if there is the lightspeed cloud api key" do 
      user = FactoryGirl.create(:user)
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      set_current_user(user)
      put :update, id: organization.slug, organization: { lightspeed_cloud_api_key: 'Some api key' }
      expect(EmailLightspeedNotificationWorker).to have_enqueued_job(organization.id, 'Some api key')
    end
  end

  describe :show do 
    describe "user not member" do 
      before do 
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        session[:user_id] = user.id
        get :show, id: organization.slug
      end
      it { should respond_with(:redirect) }
      it { should redirect_to(user_home_url) }
      it { should set_the_flash }
    end
    
    describe "when user is present" do 
      it "should render" do 
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        membership = FactoryGirl.create(:membership, user: user, organization: organization)
        session[:user_id] = user.id
        get :show, id: organization.slug
        response.code.should eq("200")
      end
    end
  end

  describe :edit do 
    it "should render when user is admin" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization, role: "admin")
      session[:user_id] = user.id
      get :edit, id: organization.slug
      response.code.should eq("200")
    end
  end

  describe :embed do 
    before do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      FactoryGirl.create(:cycle_type, name: "Bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      get :embed, id: organization.slug
    end
    it { should respond_with(:success) }
    it { should render_template(:embed) }
  end

end
