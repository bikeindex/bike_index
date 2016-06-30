require 'spec_helper'

describe OrganizationsController do
  describe 'new' do
    context 'with out user' do
      it 'renders' do
        get :new
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
        expect(response).to render_with_layout('application_revised')
      end
    end
    context 'with user' do
      it 'renders with revised_layout' do
        set_current_user(FactoryGirl.create(:user))
        get :new
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
        expect(response).to render_with_layout('application_revised')
      end
    end
  end

  describe 'create' do
    it 'creates org, membership, filters approved attrs & redirect to org with current_user' do
      expect(Organization.count).to eq(0)
      user = FactoryGirl.create(:user)
      set_current_user(user)
      org_attrs = {
        name: 'a new org',
        org_type: 'shop',
        api_access_approved: 'true',
        approved: 'true'
      }
      post :create, organization: org_attrs
      expect(Organization.count).to eq(1)
      organization = Organization.where(name: 'a new org').first
      expect(response).to redirect_to organization_manage_index_path(organization_id: organization.to_param)
      expect(organization.approved).to be_falsey
      expect(organization.api_access_approved).to be_falsey
      expect(organization.auto_user_id).to eq(user.id)
      expect(organization.memberships.count).to eq(1)
      expect(organization.memberships.first.user_id).to eq(user.id)
    end

    it "Doesn't xss" do
      expect(Organization.count).to eq(0)
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
      expect(Organization.count).to eq(1)
      organization = Organization.last
      expect(organization.name).not_to eq('<script>alert(document.cookie)</script>')
      expect(organization.website).not_to eq('<script>alert(document.cookie)</script>')
    end

    it 'mails us' do
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
        expect(ActionMailer::Base.deliveries).not_to be_empty
      end
    end
  end

  describe 'embed' do
    it 'renders embed without xframe block' do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      FactoryGirl.create(:cycle_type, slug: 'bike')
      FactoryGirl.create(:propulsion_type, name: 'Foot pedal')
      get :embed, id: organization.slug
      expect(response.code).to eq('200')
      expect(response).to render_template(:embed)
      expect(response.headers['X-Frame-Options']).not_to be_present
    end
  end

  describe 'embed_extended' do
    it 'renders embed without xframe block' do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      FactoryGirl.create(:cycle_type, slug: 'bike')
      FactoryGirl.create(:propulsion_type, name: 'Foot pedal')
      get :embed_extended, id: organization.slug, email: 'something@example.com'
      expect(response.code).to eq('200')
      expect(response).to render_template(:embed_extended)
      expect(response.headers['X-Frame-Options']).not_to be_present
      expect(assigns(:persist_email)).to be_truthy
    end
  end

  describe 'embed' do
    it 'renders embed without xframe block' do
      organization = FactoryGirl.create(:organization)
      bike = FactoryGirl.create(:bike)
      get :embed_create_success, id: organization.slug, bike_id: bike.id
      expect(response.code).to eq('200')
      expect(response).to render_template(:embed_create_success)
      expect(response.headers['X-Frame-Options']).not_to be_present
    end
  end

  describe 'lightspeed_integration' do
    context 'revised' do
      it 'renders with revised_layout' do
        get :lightspeed_integration
        expect(response.status).to eq(200)
        expect(response).to render_template(:lightspeed_integration)
        expect(response).to render_with_layout('application_revised')
      end
    end
  end
end
