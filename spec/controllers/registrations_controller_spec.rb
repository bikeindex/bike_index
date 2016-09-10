require 'spec_helper'

describe RegistrationsController do
  before do
    CycleType.bike
    PropulsionType.foot_pedal
  end
  let(:user) { FactoryGirl.create(:user) }
  let(:auto_user) { FactoryGirl.create(:organization_auto_user) }
  let(:organization) { auto_user.organizations.first }

  describe 'new' do
    it 'renders with the embeded form, no xframing' do
      set_current_user(user)
      get :new, organization_id: organization.id, stolen: true
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
      expect(response).to render_with_layout('application_revised')
      expect(flash).to_not be_present
      expect(response.headers['X-Frame-Options']).to be_present
    end
  end
  describe 'embed' do
    context 'no organization' do
      context 'no user' do
        it 'renders' do
          get :embed, stolen: true
          expect(response.status).to eq(200)
          expect(response).to render_template(:embed)
          expect(flash).to_not be_present
          expect(assigns(:stolen)).to be_truthy
          expect(assigns(:creator)).to be_nil
          expect(assigns(:owner_email)).to be_nil
        end
      end
      context 'with user' do
        it 'renders does not set creator' do
          set_current_user(user)
          get :embed
          expect(response.status).to eq(200)
          expect(response).to render_template(:embed)
          expect(flash).to_not be_present
          expect(assigns(:stolen)).to eq 0
          expect(assigns(:creator)).to be_nil
          expect(assigns(:owner_email)).to eq user.email
          expect(response.headers['X-Frame-Options']).not_to be_present
        end
      end
    end
    context 'with organization' do
      context 'no user' do
        it 'renders' do
          get :embed, organization_id: organization.to_param, simple_header: true
          expect(response.status).to eq(200)
          expect(response).to render_template(:embed)
          expect(flash).to_not be_present
          expect(response.headers['X-Frame-Options']).not_to be_present
          expect(assigns(:stolen)).to eq 0
          expect(assigns(:organization)).to eq organization
          expect(assigns(:creator)).to be_nil
          expect(assigns(:simple_header)).to be_truthy
        end
      end
      context 'with user' do
        it 'renders, testing variables' do
          set_current_user(user)
          get :embed, organization_id: organization.id, stolen: true
          expect(response.status).to eq(200)
          expect(response).to render_template(:embed)
          expect(flash).to_not be_present
          expect(response.headers['X-Frame-Options']).not_to be_present
          # Since we're creating these in line, actually test the rendered body
          body = response.body
          # Owner email
          owner_email_input = body[/value=.*id..b_param_owner_email*/i]
          email_value = owner_email_input.gsub(/value=./, '').match(/\A[^\"]*/)[0]
          expect(email_value).to eq user.email
          # creation_organization
          creator_organization_input = body[/value=.*id..b_param_creation_organization_id/i]
          creator_organization_value = creator_organization_input.gsub(/value=./, '').match(/\A[^\"]*/)[0]
          expect(creator_organization_value).to eq organization.id.to_s

          expect(assigns(:simple_header)).to be_falsey
          expect(assigns(:stolen)).to be_truthy
          expect(assigns(:organization)).to eq organization
          expect(assigns(:creator)).to be_nil
          expect(assigns(:owner_email)).to eq user.email
        end
      end
    end
  end
  describe 'create' do
    let(:manufacturer) { FactoryGirl.create(:manufacturer) }
    let(:color) { FactoryGirl.create(:color) }
    context 'invalid creation' do
      context 'email not set, sets simple_header' do
        it 'does not create a bparam, rerenders new with all assigned values' do
          attrs = {
            manufacturer_id: manufacturer.id,
            stolen: true,
            creator_id: 21,
            primary_frame_color_id: color.id,
            secondary_frame_color_id: 12,
            tertiary_frame_color_id: 222,
            creation_organization_id: 9292
          }
          expect do
            post :create, simple_header: true, b_param: attrs
          end.to change(BParam, :count).by 0
          expect(response).to render_template(:new)
          expect(assigns(:simple_header)).to be_truthy
          b_param = assigns(:b_param)
          attrs.except(:creator_id).each do |key, value|
            expect(b_param.send(key).to_s).to eq value.to_s
          end
          expect(b_param.creator_id).to be_nil
          expect(b_param.origin).to eq 'embed_partial'
        end
      end
    end
    context 'valid creation' do
      context 'nothing except email set' do
        it 'creates a new bparam and renders' do
          post :create, b_param: { owner_email: 'something@stuff.com' }, simple_header: true
          expect(response).to render_template(:create)
          b_param = BParam.last
          expect(b_param.owner_email).to eq 'something@stuff.com'
          expect(b_param.origin).to eq 'embed_partial'
          expect(EmailPartialRegistrationWorker).to have_enqueued_job(b_param.id)
          expect(response.headers['X-Frame-Options']).not_to be_present
          expect(assigns(:simple_header)).to be_truthy
        end
      end
      context 'all values set' do
        it 'creates a new bparam and renders' do
          attrs = {
            manufacturer_id: manufacturer.id,
            primary_frame_color_id: color.id,
            secondary_frame_color_id: color.id,
            tertiary_frame_color_id: 222,
            owner_email: 'ks78xxxxxx@stuff.com',
            creation_organization_id: 21
          }
          post :create, b_param: attrs
          expect(response).to render_template(:create)
          b_param = BParam.last
          expect(response.headers['X-Frame-Options']).not_to be_present
          attrs.each do |key, value|
            expect(b_param.send(key).to_s).to eq value.to_s
          end
          expect(b_param.origin).to eq 'embed_partial'
          expect(EmailPartialRegistrationWorker).to have_enqueued_job(b_param.id)
        end
      end
    end
  end
end
