require 'spec_helper'

describe OrganizationsController do
  describe 'new' do
    describe 'it should render the page without current user' do
      before do
        get :new
      end
      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:new) }
    end
    context 'legacy' do
      it 'renders with content layout' do
        get :new
        expect(response.status).to eq(200)
        expect(response).to render_template(:new)
        expect(response).to render_with_layout('content')
      end
    end
    context 'revised' do
      it 'renders with revised_layout' do
        allow(controller).to receive(:revised_layout_enabled?) { true }
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
      expect(response).to redirect_to edit_organization_url(organization)
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

  describe 'update' do
    it 'updates some fields, send a message about maps' do
      user = FactoryGirl.create(:user)
      user2 = FactoryGirl.create(:user)
      org = { available_invitation_count: '10',
              sent_invitation_count: '1',
              is_suspended: false,
              embedable_user_email: user.email,
              auto_user_id: user.id,
              show_on_map: false,
              api_access_approved: false,
              access_token: 'stuff7',
              new_bike_notification: 'stuff8' }
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: user, organization: organization, role: 'admin')
      FactoryGirl.create(:membership, user: user2, organization: organization)
      organization.update_attributes(org)
      organization.save
      user.reload
      set_current_user(user)
      org_update = { available_invitation_count: '20',
                     sent_invitation_count: '0',
                     is_suspended: true,
                     embedable_user_email: user2.email,
                     auto_user_id: user2.id,
                     api_access_approved: true,
                     access_token: 'things7',
                     new_bike_notification: 'things8',
                     website: 'http://www.drseuss.org',
                     name: 'some new name',
                     org_type: 'shop',
                     wants_to_be_shown: true
      }
      put :update, id: organization.slug, organization: org_update
      expect(response.code).to eq('302')
      expect(organization.reload.name).to eq('some new name')
      expect(organization.website).to eq('http://www.drseuss.org')
      org.keys.each do |k|
        unless k == :wants_to_be_shown || k == :org_type

          expect(organization.send(k).to_s).to eq((org[k]).to_s)
        end
      end
      msg = Feedback.last
      expect(msg.feedback_type).to eq('organization_map')
      expect(msg.feedback_hash[:organization_id]).to eq(organization.id)
    end

    it 'sends an admin notification if there is the lightspeed retail api key' do
      user = FactoryGirl.create(:user)
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: user, organization: organization, role: 'admin')
      set_current_user(user)
      put :update, id: organization.slug, organization: { lightspeed_cloud_api_key: 'Some api key' }
      expect(EmailLightspeedNotificationWorker).to have_enqueued_job(organization.id, 'Some api key')
    end
  end

  describe 'show' do
    describe 'user not member' do
      before do
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        set_current_user(user)
        get :show, id: organization.slug
      end
      it { is_expected.to respond_with(:redirect) }
      it { is_expected.to redirect_to(user_home_url) }
      it { is_expected.to set_flash }
    end

    describe 'when user is present' do
      it 'renders' do
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        membership = FactoryGirl.create(:membership, user: user, organization: organization)
        set_current_user(user)
        get :show, id: organization.slug
        expect(response.code).to eq('200')
      end
    end
  end

  describe 'edit' do
    it 'renders when user is admin' do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization, role: 'admin')
      set_current_user(user)
      get :edit, id: organization.slug
      expect(response.code).to eq('200')
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
      expect(response).to render_template(:embed)
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
end
