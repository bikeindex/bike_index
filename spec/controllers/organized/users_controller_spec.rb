require 'spec_helper'

describe Organized::UsersController, type: :controller do
  context 'logged_in_as_organization_admin' do
    include_context :logged_in_as_organization_admin
    describe 'index' do
      it 'renders' do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
      end
    end

    describe 'new' do
      it 'renders the page' do
        get :new, organization_id: organization.to_param
        expect(response.code).to eq('200')
        expect(response).to render_template :new
        expect(response).to render_with_layout 'application_revised'
      end
    end

    describe 'edit' do
      context 'membership' do
        let(:membership) { FactoryGirl.create(:existing_membership, organization: organization) }
        it 'renders the page' do
          get :edit, organization_id: organization.to_param, id: membership.id
          expect(assigns(:membership)).to eq membership
          expect(response.code).to eq('200')
          expect(response).to render_template :edit
          expect(response).to render_with_layout 'application_revised'
        end
      end
      context 'organization_invitation' do
        let(:invitation) { FactoryGirl.create(:organization_invitation, organization: organization) }
        it 'renders the page' do
          get :edit, organization_id: organization.to_param, id: invitation.id, is_invitation: true
          expect(assigns(:organization_invitation)).to eq invitation
          expect(response.code).to eq('200')
          expect(response).to render_template :edit
          expect(response).to render_with_layout 'application_revised'
        end
      end
    end

    describe 'update' do
      context 'organization_invitation' do
        let(:organization_invitation) { FactoryGirl.create(:organization_invitation, organization: organization, inviter: user) }
        let(:organization_invitation_params) do
          {
            membership_role: 'admin',
            name: 'something',
            inviter_id: 333,
            invitee_email: 'new_bike_email@bike_shop.com'
          }
        end
        it 'updates name and role, ignores email' do
          og_email = organization_invitation.invitee_email
          expect do
            put :update, organization_id: organization.to_param,
                         id: organization_invitation.id,
                         is_invitation: true, organization_invitation: organization_invitation_params
          end.to change(OrganizationInvitation, :count).by(0)
          expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
          expect(flash[:success]).to be_present
          organization_invitation.reload
          expect(organization_invitation.membership_role).to eq 'admin'
          expect(organization_invitation.inviter).to eq user
          expect(organization_invitation.invitee_email).to eq og_email
        end
      end
      context 'membership' do
        context 'other valid membership' do
          let(:membership) { FactoryGirl.create(:existing_membership, organization: organization, role: 'member') }
          let(:membership_params) { { role: 'admin', user_id: 333 } }
          it 'updates the role' do
            og_user = membership.user
            put :update, organization_id: organization.to_param, id: membership.id,
                         membership: membership_params
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:success]).to be_present
            membership.reload
            expect(membership.role).to eq 'admin'
            expect(membership.user).to eq og_user
          end
        end
        context 'marking self member' do
          let(:membership) { user.memberships.first }
          it 'does not update the membership' do
            put :update, organization_id: organization.to_param, id: membership.id,
                         membership: { role: 'member' }
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:error]).to be_present
            membership.reload
            expect(membership.role).to eq 'admin'
            expect(membership.user).to eq user
          end
        end
      end
    end

    describe 'destroy' do
      context 'organization_invitation' do
        let(:organization_invitation) { FactoryGirl.create(:organization_invitation, organization: organization, inviter: user) }
        it 'destroys' do
          expect(organization_invitation).to be_present
          count = organization.available_invitation_count
          expect do
            delete :destroy, organization_id: organization.to_param,
                             id: organization_invitation.id, is_invitation: true
          end.to change(OrganizationInvitation, :count).by(-1)
          expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
          expect(flash[:success]).to be_present
          organization.reload
          expect(organization.available_invitation_count).to eq(count + 1)
        end
      end
      context 'membership' do
        context 'other valid membership' do
          let(:membership) { FactoryGirl.create(:existing_membership, organization: organization, role: 'member') }
          it 'destroys the membership' do
            expect(membership).to be_present
            count = organization.available_invitation_count
            expect do
              delete :destroy, organization_id: organization.to_param, id: membership.id
            end.to change(Membership, :count).by(-1)
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:success]).to be_present
            organization.reload
            expect(organization.available_invitation_count).to eq(count + 1)
          end
        end
        context 'marking self member' do
          let(:membership) { user.memberships.first }
          it 'does not destroy' do
            count = organization.available_invitation_count
            expect do
              delete :destroy, organization_id: organization.to_param, id: membership.id
            end.to change(Membership, :count).by(0)
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:error]).to be_present
            organization.reload
            expect(organization.available_invitation_count).to eq count
          end
        end
      end
    end

    describe 'create' do
      let(:organization_invitation_params) do
        {
          membership_role: 'member',
          invitee_name: 'cool',
          invitee_email: 'bike_email@bike_shop.com'
        }
      end
      context 'available invitations' do
        it 'creates organization_invitation, reduces invitation tokens by 1' do
          expect(organization.available_invitation_count).to eq 5
          expect do
            put :create, organization_id: organization.to_param,
                         organization_invitation: organization_invitation_params
          end.to change(OrganizationInvitation, :count).by(1)
          expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
          expect(flash[:success]).to be_present
          organization.reload
          expect(organization.available_invitation_count).to eq 4
          organization_invitation = OrganizationInvitation.last
          expect(organization_invitation.membership_role).to eq 'member'
          expect(organization_invitation.inviter).to eq user
          expect(organization_invitation.invitee_email).to eq 'bike_email@bike_shop.com'
          expect(organization_invitation.invitee_name).to eq 'cool'
          expect(organization.sent_invitation_count).to eq 1
        end
      end
      context 'no available invitations' do
        it 'does not create a new organization_invitation' do
          organization.update_attributes(available_invitation_count: 0)
          expect do
            put :create, organization_id: organization.to_param, organization_invitation: organization_invitation_params
          end.to change(OrganizationInvitation, :count).by(0)
          expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
          expect(flash[:error]).to be_present
        end
      end
    end
  end
end
