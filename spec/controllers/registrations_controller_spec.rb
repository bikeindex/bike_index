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
    context 'no organization' do
      context 'no user' do
        it 'renders' do
          get :new, stolen: true
          expect(response.status).to eq(200)
          expect(response).to render_template(:new)
          expect(flash).to_not be_present
        end
      end
      context 'with user' do
        it 'renders, sets creator to user' do
          set_current_user(user)
          get :new
          expect(response.status).to eq(200)
          expect(response).to render_template(:new)
          expect(flash).to_not be_present
          # Creator is user
          creator_input = response.body[/value=.*id..b_param_creator_id..*.\d*/i]
          creator_value = creator_input.gsub(/value=./, '').match(/\A[^\"]*/)[0]
          expect(creator_value).to eq user.id.to_s
        end
      end
    end
    context 'with organization' do
      context 'no user' do
        it 'renders' do
          get :new, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template(:new)
          expect(flash).to_not be_present
        end
      end
      context 'with user' do
        it 'renders' do
          set_current_user(user)
          get :new, organization_id: organization.id
          expect(response.status).to eq(200)
          expect(response).to render_template(:new)
          expect(flash).to_not be_present
          # Since we're creating these in line, actually test the rendered body
          body = response.body
          # Owner email
          owner_email_input = body[/value=.*id..b_param_owner_email*/i]
          email_value = owner_email_input.gsub(/value=./, '').match(/\A[^\"]*/)[0]
          expect(email_value).to eq user.email
          # Creator
          creator_input = body[/value=.*id..b_param_creator_id..*.\d*/i]
          creator_value = creator_input.gsub(/value=./, '').match(/\A[^\"]*/)[0]
          expect(creator_value).to eq organization.auto_user_id.to_s
          # creation_organization
          creator_organization_input = body[/value=.*id..b_param_creation_organization_id/i]
          creator_organization_value = creator_organization_input.gsub(/value=./, '').match(/\A[^\"]*/)[0]
          expect(creator_organization_value).to eq organization.id.to_s
        end
      end
    end
  end
  describe 'create' do
    let(:manufacturer) { FactoryGirl.create(:manufacturer) }
    let(:color) { FactoryGirl.create(:color) }
    context 'invalid creation' do
      context 'email not set' do
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
            post :create, b_param: attrs
          end.to change(BParam, :count).by 0
          expect(response).to render_template(:new)
          b_param = assigns(:b_param)
          attrs.each do |key, value|
            expect(b_param.send(key).to_s).to eq value.to_s
          end
        end
      end
    end
    context 'valid creation' do
      context 'nothing except email set' do
        it 'creates a new bparam and renders' do
          post :create, b_param: { owner_email: 'something@stuff.com' }
          expect(response).to render_template(:create)
          b_param = BParam.last
          expect(b_param.owner_email).to eq 'something@stuff.com'
          expect(EmailPartialRegistrationWorker).to have_enqueued_job(b_param.id)
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
            creation_organization_id: 21,
            creator_id: 333
          }
          post :create, b_param: attrs
          expect(response).to render_template(:create)
          b_param = BParam.last
          attrs.each do |key, value|
            expect(b_param.send(key).to_s).to eq value.to_s
          end
          expect(EmailPartialRegistrationWorker).to have_enqueued_job(b_param.id)
        end
      end
    end
  end
end
