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
          # Since we're creating these in line, actually test the rendered body
          body = response.body
          # Owner email
          owner_email_input = body[/value=.*id..b_param_owner_email*/i]
          email_value = owner_email_input.gsub(/value=./,'').match(/\A[^\"]*/)[0]
          expect(email_value).to eq user.email
          # Creator
          creator_input = body[/value=.*id..b_param_creator_id..*.\d*/i]
          creator_value = creator_input.gsub(/value=./,'').match(/\A[^\"]*/)[0]
          expect(creator_value).to eq organization.auto_user_id.to_s
          # creation_organization
          creator_organization_input = body[/value=.*id..b_param_creation_organization_id/i]
          creator_organization_value = creator_organization_input.gsub(/value=./,'').match(/\A[^\"]*/)[0]
          expect(creator_organization_value).to eq organization.id.to_s
        end
      end
    end
  end
  describe 'create' do
    # context 'no organization' do
    #   context 'no user' do
    #     it 'renders' do
    #       get :new, stolen: true
    #       expect(response).to render_template(:create)
    #     end
    #   end
    #   context 'with user' do
    #     it 'renders' do
    #       set_current_user(user)
    #       get :new
    #       expect(response).to render_template(:create)
    #       expect(flash).to_not be_present
    #     end
    #   end
    # end
    # context 'with organization' do
    #   context 'no user' do
    #     it 'renders' do
    #       get :new, organization_id: organization.to_param
    #       expect(response).to render_template(:create)
    #     end
    #   end
    #   context 'with user' do
    #     it 'renders' do
    #       set_current_user(user)
    #       get :new, organization_id: organization.id
    #       expect(response).to render_template(:create)
    #     end
    #   end
    # end
  end
end