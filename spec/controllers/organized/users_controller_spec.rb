require "rails_helper"

RSpec.describe Organized::UsersController, type: :controller do
  context "logged_in_as_organization_member" do
    include_context :logged_in_as_organization_member
    describe "index" do
      it "redirects" do
        get :index, organization_id: organization.to_param
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "new" do
      it "redirects" do
        get :new, organization_id: organization.to_param
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "update" do
      context "membership" do
        let(:membership) { FactoryBot.create(:membership, organization: organization, sender: user) }
        let(:membership_params) do
          {
            role: "admin",
            name: "something",
            invited_email: "new_bike_email@bike_shop.com",
          }
        end
        it "does not update" do
          put :update, organization_id: organization.to_param,
                       id: membership.id,
                       membership: membership_params
          expect(response).to redirect_to(organization_root_path)
          expect(flash[:error]).to be_present
          membership.reload
          expect(membership.role).to eq "member"
        end
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "index" do
      it "renders" do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
      end
    end

    describe "new" do
      it "renders the page" do
        get :new, organization_id: organization.to_param
        expect(response.code).to eq("200")
        expect(response).to render_template :new
      end
    end

    describe "edit" do
      context "membership" do
        let(:membership) { FactoryBot.create(:membership_claimed, organization: organization) }
        it "renders the page" do
          get :edit, organization_id: organization.to_param, id: membership.id
          expect(assigns(:membership)).to eq membership
          expect(response.code).to eq("200")
          expect(response).to render_template :edit
        end
      end
    end

    describe "update" do
      context "membership" do
        context "other valid membership" do
          let(:membership) { FactoryBot.create(:membership_claimed, organization: organization, role: "member") }
          let(:membership_params) { { role: "admin", user_id: 333 } }
          it "updates the role" do
            og_user = membership.user
            put :update, organization_id: organization.to_param, id: membership.id,
                         membership: membership_params
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:success]).to be_present
            membership.reload
            expect(membership.role).to eq "admin"
            expect(membership.user).to eq og_user
          end
        end
        context "marking self member" do
          let(:membership) { user.memberships.first }
          it "does not update the membership" do
            put :update, organization_id: organization.to_param, id: membership.id,
                         membership: { role: "member" }
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:error]).to be_present
            membership.reload
            expect(membership.role).to eq "admin"
            expect(membership.user).to eq user
          end
        end
      end
    end

    describe "destroy" do
      context "membership unclaimed" do
        let(:membership) { FactoryBot.create(:membership, organization: organization, sender: user) }
        it "destroys" do
          expect(membership.claimed?).to be_falsey
          count = organization.remaining_invitation_count
          expect do
            delete :destroy, organization_id: organization.to_param,
                             id: membership.id
          end.to change(Membership, :count).by(-1)
          expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
          expect(flash[:success]).to be_present
          organization.reload
          expect(organization.remaining_invitation_count).to eq(count + 1)
        end
      end
      context "membership" do
        context "other valid membership" do
          let(:membership) { FactoryBot.create(:membership_claimed, organization: organization, role: "member") }
          it "destroys the membership" do
            expect(membership.claimed?).to be_truthy
            count = organization.remaining_invitation_count
            expect do
              delete :destroy, organization_id: organization.to_param, id: membership.id
            end.to change(Membership, :count).by(-1)
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:success]).to be_present
            organization.reload
            expect(organization.remaining_invitation_count).to eq(count + 1)
          end
        end
        context "marking self member" do
          let(:membership) { user.memberships.first }
          it "does not destroy" do
            count = organization.remaining_invitation_count
            expect do
              delete :destroy, organization_id: organization.to_param, id: membership.id
            end.to change(Membership, :count).by(0)
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:error]).to be_present
            organization.reload
            expect(organization.remaining_invitation_count).to eq count
          end
        end
      end
    end

    describe "create" do
      let(:membership_params) do
        {
          role: "member",
          invited_email: "bike_email@bike_shop.com",
        }
      end
      context "no email" do
        it "fails" do
          expect do
            put :create, organization_id: organization.to_param,
                         membership: membership_params.merge(invited_email: " ")
          end.to change(Membership, :count).by(0)
          expect(assigns(:membership).errors.full_messages).to be_present
        end
      end
      context "available invitations" do
        it "creates membership, reduces invitation tokens by 1" do
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(organization.remaining_invitation_count).to eq 4
            expect do
              put :create, organization_id: organization.to_param,
                           membership: membership_params
            end.to change(Membership, :count).by(1)
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:success]).to be_present
            organization.reload
            expect(organization.remaining_invitation_count).to eq 3
            membership = Membership.last
            membership.enqueue_processing_worker # TODO: Rails 5 update - this is an after_commit issue
            membership.reload
            expect(membership.role).to eq "member"
            expect(membership.sender).to eq user
            expect(membership.invited_email).to eq "bike_email@bike_shop.com"
            expect(membership.claimed?).to be_falsey
            expect(membership.email_invitation_sent_at).to be_present
            expect(organization.sent_invitation_count).to eq 2
            expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          end
        end
      end
      context "no available invitations" do
        it "does not create a new membership" do
          organization.update_attributes(available_invitation_count: 1)
          expect do
            put :create, organization_id: organization.to_param, membership: membership_params
          end.to change(Membership, :count).by(0)
          expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
          expect(flash[:error]).to be_present
        end
      end
    end
  end
end
