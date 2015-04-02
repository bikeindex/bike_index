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
    it "creates org, membership, filters approved attrs & redirect to org with current_user" do 
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
      response.should redirect_to edit_organization_url(organization)
      organization.approved.should be_false
      organization.api_access_approved.should be_false
      organization.auto_user_id.should eq(user.id)
      organization.memberships.count.should eq(1)
      organization.memberships.first.user_id.should eq(user.id)
    end

    it "Doesn't xss" do
      Organization.count.should eq(0)
      user = FactoryGirl.create(:user)
      set_current_user(user)
      org_attrs = {
        name: '<script>alert(document.cookie)</script>',
        website: '<script>alert(document.cookie)</script>',
        org_type: 'shop',
        api_access_approved: 'true',
        approved: 'true'
      }
      post :create, organization: org_attrs
      Organization.count.should eq(1)
      organization = Organization.last
      organization.name.should_not eq('<script>alert(document.cookie)</script>')
      organization.website.should_not eq('<script>alert(document.cookie)</script>')
    end

    it "mails us" do 
      Sidekiq::Testing.inline! do
        user = FactoryGirl.create(:user)
        set_current_user(user)
        org_attrs = {
          name: 'a new org',
          org_type: 'shop',
          api_access_approved: 'true',
          approved: 'true'
        }
        ActionMailer::Base.deliveries = []
        post :create, organization: org_attrs
        ActionMailer::Base.deliveries.should_not be_empty
      end
    end
  end

  describe :update do
    it "updates some fields, send a message about maps" do
      user = FactoryGirl.create(:user)
      user2 = FactoryGirl.create(:user)
      org = {available_invitation_count:"10",
        sent_invitation_count: "1",
        default_bike_token_count: "2",
        is_suspended: false,
        embedable_user_email: user.email,
        auto_user_id: user.id,
        show_on_map: false,
        api_access_approved: false,
        access_token: "stuff7",
        new_bike_notification: "stuff8"}
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: user, organization: organization, role: 'admin')
      FactoryGirl.create(:membership, user: user2, organization: organization)
      organization.update_attributes(org)
      organization.save
      user.reload
      set_current_user(user)
      org_update = {available_invitation_count:"20",
        sent_invitation_count: "0",
        default_bike_token_count: "39",
        is_suspended: true,
        embedable_user_email: user2.email,
        auto_user_id: user2.id,
        api_access_approved: true,
        access_token: "things7",
        new_bike_notification: "things8",
        website: 'http://www.drseuss.org',
        name: 'some new name',
        org_type: 'shop',
        wants_to_be_shown: true
      }
      put :update, {id: organization.slug, organization: org_update}
      response.code.should eq('302')
      organization.reload.name.should eq('some new name')
      organization.website.should eq('http://www.drseuss.org')
      org.keys.each do |k|
        unless k == :wants_to_be_shown || k == :org_type

          "#{organization.send(k)}".should eq("#{org[k]}")
        end
      end
      msg = Feedback.last
      msg.feedback_type.should eq('organization_map')
      msg.feedback_hash[:organization_id].should eq(organization.id)
    end

    it "sends an admin notification if there is the lightspeed retail api key" do 
      user = FactoryGirl.create(:user)
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: user, organization: organization, role: 'admin')
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
        set_current_user(user)
        get :show, id: organization.slug
      end
      it { should respond_with(:redirect) }
      it { should redirect_to(user_home_url) }
      it { should set_the_flash }
    end
    
    describe "when user is present" do 
      it "renders" do 
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        membership = FactoryGirl.create(:membership, user: user, organization: organization)
        set_current_user(user)
        get :show, id: organization.slug
        response.code.should eq("200")
      end
    end
  end

  describe :edit do 
    it "renders when user is admin" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization, role: "admin")
      set_current_user(user)
      get :edit, id: organization.slug
      response.code.should eq("200")
    end
  end

  describe :embed do 
    it "renders embed" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      get :embed, id: organization.slug
      response.code.should eq("200")
      response.should render_template(:embed)
      response.headers['X-Frame-Options'].should_not be_present
    end
  end

  describe :embed_extended do 
    it "renders embed" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      FactoryGirl.create(:cycle_type, slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      get :embed_extended, id: organization.slug
      response.code.should eq("200")
      response.should render_template(:embed)
      response.headers['X-Frame-Options'].should_not be_present
    end
  end

end
