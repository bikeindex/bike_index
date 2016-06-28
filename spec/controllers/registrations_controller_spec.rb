require 'spec_helper'

describe RegistrationsController do
  before do
    CycleType.bike
    PropulsionType.foot_pedal
  end
  let(:user) { FactoryGirl.create(:user) }
  let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
  let(:auto_user) { organization.auto_user }

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
        it 'renders' do
          set_current_user(user)
          get :new
          expect(response.status).to eq(200)
          expect(response).to render_template(:new)
          expect(flash).to_not be_present
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
          # Since we're creating these in line, actually test the rendered bodyy
          body = response.body
          # Owner email
          owner_email_input = body[/id..b_param_owner_email[^v]*value=.[^\"]*/i]
          expect(owner_email_input[/[^\"]*\z/]).to eq user.email
          # Creator
          creator_input = body[/.input id..b_param_creator_id..[^v]*value=.\d*/i]
          expect(creator_input[/\d*\z/]).to eq organization.auto_user_id.to_s
          # creation_organization
          creator_organization_id = body[/.input id..b_param_creation_organization_id..[^v]*value=.\d*/i]
          expect(creator_organization_id[/\d*\z/]).to eq organization.id.to_s
        end
      end
    end
  end
end