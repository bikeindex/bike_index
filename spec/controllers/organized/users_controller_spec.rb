require "rails_helper"

RSpec.describe Organized::UsersController, type: :controller do
  context "logged_in_as_organization_member" do
    include_context :logged_in_as_organization_member
    describe "index" do
      it "redirects" do
        get :index, params: { organization_id: organization.to_param }
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "new" do
      it "redirects" do
        get :new, params: { organization_id: organization.to_param }
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
          put :update, params: {
                         organization_id: organization.to_param,
                         id: membership.id,
                         membership: membership_params,
                       }
          expect(response).to redirect_to(organization_root_path)
          expect(flash[:error]).to be_present
          expect(membership.role).to eq "member"
        end
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :logged_in_as_organization_admin
    describe "index" do
      it "renders" do
        get :index, params: { organization_id: organization.to_param }
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq organization
      end
    end

    describe "new" do
      it "renders the page" do
        get :new, params: { organization_id: organization.to_param }
        expect(response.code).to eq("200")
        expect(response).to render_template :new
      end
    end

    describe "edit" do
      context "membership" do
        let(:membership) { FactoryBot.create(:membership_claimed, organization: organization) }
        it "renders the page" do
          get :edit, params: { organization_id: organization.to_param, id: membership.id }
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
            put :update, params: { organization_id: organization.to_param, id: membership.id, membership: membership_params }
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
            put :update, params: { organization_id: organization.to_param, id: membership.id, membership: { role: "member" } }
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
            delete :destroy, params: {
                               organization_id: organization.to_param,
                               id: membership.id,
                             }
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
              delete :destroy, params: { organization_id: organization.to_param, id: membership.id }
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
              delete :destroy, params: { organization_id: organization.to_param, id: membership.id }
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
      before { Sidekiq::Worker.clear_all }
      let(:membership_params) do
        {
          role: "member",
          invited_email: "bike_email@bike_shop.com",
        }
      end
      context "no email" do
        it "fails" do
          expect do
            put :create, params: {
                           organization_id: organization.to_param,
                           membership: membership_params.merge(invited_email: " "),
                         }
          end.to change(Membership, :count).by(0)
          expect(assigns(:membership).errors.full_messages).to be_present
        end
      end
      context "available invitations" do
        it "creates membership, reduces invitation tokens by 1" do
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(organization.remaining_invitation_count).to eq 4
            expect(User.count).to eq 2
            expect do
              put :create, params: {
                             organization_id: organization.to_param,
                             membership: membership_params,
                           }
            end.to change(Membership, :count).by(1)
            expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
            expect(flash[:success]).to be_present
            organization.reload
            expect(organization.remaining_invitation_count).to eq 3
            membership = Membership.last
            expect(membership.role).to eq "member"
            expect(membership.sender).to eq user
            expect(membership.invited_email).to eq "bike_email@bike_shop.com"
            expect(membership.claimed?).to be_falsey
            expect(membership.email_invitation_sent_at).to be_present
            expect(organization.sent_invitation_count).to eq 2
            expect(User.count).to eq 2 # make sure we aren't creating an extra user (aka not doing passwordless users)
            expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          end
        end
      end
      context "no available invitations" do
        it "does not create a new membership" do
          organization.update_attributes(available_invitation_count: 1)
          expect do
            put :create, params: { organization_id: organization.to_param, membership: membership_params }
          end.to change(Membership, :count).by(0)
          expect(response).to redirect_to organization_users_path(organization_id: organization.to_param)
          expect(flash[:error]).to be_present
        end
      end
      context "multiple invitations, more than available" do
        let(:multiple_emails_invited) { %w[stuff@stuff.com stuff@stuff2.com stuff@stuff.com stuff3@stuff.com stuff4@stuff.com stuff5@stuff.com stuff6@stuff.com] }
        it "renders error, doesn't create any" do
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(organization.remaining_invitation_count).to eq 4
            expect do
              put :create, params: {
                             organization_id: organization.to_param,
                             membership: membership_params,
                             multiple_emails_invited: multiple_emails_invited.join("\n"),
                           }
            end.to_not change(Membership, :count)
          end
        end
      end
      context "multiple invitations" do
        let(:multiple_emails_invited) { %w[stuff@stuff.com stuff@stuff2.com stuff@stuff.com stuff3@stuff.com stuff4@stuff.com stuff4@stuff.com stuff4@stuff.com] }
        let(:target_invited_emails) { %w[stuff@stuff.com stuff@stuff2.com stuff3@stuff.com stuff4@stuff.com] + [user.email] }
        it "invites, dedupes" do
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(organization.remaining_invitation_count).to eq 4
            expect do
              put :create, params: {
                             organization_id: organization.to_param,
                             membership: membership_params,
                             multiple_emails_invited: multiple_emails_invited.join("\n ") + "\n",
                           }
            end.to change(Membership, :count).by 4
            expect(organization.remaining_invitation_count).to eq 0
            expect(organization.sent_invitation_count).to eq 5
            expect(organization.memberships.pluck(:invited_email)).to match_array(target_invited_emails)
            expect(organization.users.count).to eq 1
            expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          end
        end
        context "auto_passwordless_users" do
          let(:paid_feature) { FactoryBot.create(:paid_feature, amount_cents: 0, feature_slugs: ["passwordless_users"]) }
          let!(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0, organization: organization) }
          it "invites whatever" do
            # We have to actually assign the invoice here because membership creation bumps the organization -
            # and the organization needs to have the paid feature after the first membership is created
            Sidekiq::Testing.inline! do
              invoice.update_attributes(paid_feature_ids: [paid_feature.id])
              expect(organization.reload.enabled_feature_slugs).to eq(["passwordless_users"])

              ActionMailer::Base.deliveries = []
              expect(organization.remaining_invitation_count).to eq 4
              expect(organization.users.count).to eq 1
              expect(organization.users.confirmed.count).to eq 1

              expect do
                put :create, params: {
                               organization_id: organization.to_param,
                               membership: membership_params,
                               multiple_emails_invited: multiple_emails_invited.join("\n ") + "\n",
                             }
              end.to change(Membership, :count).by 4

              expect(organization.remaining_invitation_count).to eq 0
              expect(organization.sent_invitation_count).to eq 5
              expect(organization.memberships.pluck(:invited_email)).to match_array(target_invited_emails)

              expect(organization.users.count).to eq 5
              expect(organization.users.confirmed.count).to eq 5
              expect(organization.users.pluck(:email)).to match_array(target_invited_emails)
              expect(ActionMailer::Base.deliveries.empty?).to be_truthy
            end
          end
        end
      end
    end
  end
end
