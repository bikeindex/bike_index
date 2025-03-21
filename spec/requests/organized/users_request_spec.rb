require "rails_helper"

RSpec.describe Organized::UsersController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/users" }
  context "logged_in_as_organization_user" do
    include_context :request_spec_logged_in_as_organization_user
    describe "index" do
      it "redirects" do
        get base_url, params: {organization_id: current_organization.to_param}
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "new" do
      it "redirects" do
        get "#{base_url}/new", params: {organization_id: current_organization.to_param}
        expect(response).to redirect_to(organization_root_path)
        expect(flash[:error]).to be_present
      end
    end

    describe "update" do
      context "organization_role" do
        let(:organization_role) { FactoryBot.create(:organization_role, organization: current_organization, sender: current_user) }
        let(:organization_role_params) do
          {
            role: "admin",
            name: "something",
            invited_email: "new_bike_email@bike_shop.com"
          }
        end
        it "does not update" do
          put "#{base_url}/#{organization_role.id}", params: {
            organization_id: current_organization.to_param,
            organization_role: organization_role_params
          }
          expect(response).to redirect_to(organization_root_path)
          expect(flash[:error]).to be_present
          expect(organization_role.role).to eq "member"
        end
      end
    end
  end

  context "logged_in_as_organization_admin" do
    include_context :request_spec_logged_in_as_organization_admin
    describe "index" do
      let!(:user2) { FactoryBot.create(:organization_user, organization: current_organization, email: "jill@org.edu", name: "monica") }
      it "renders" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(assigns(:current_organization)).to eq current_organization
        expect(assigns(:organization_roles).pluck(:user_id)).to match_array([current_user.id, user2.id])
        current_organization.reload
        expect(current_organization.organization_roles.admin_text_search("jill").pluck(:user_id)).to eq([user2.id])
        expect(current_organization.organization_roles.admin_text_search("monica").pluck(:user_id)).to eq([user2.id])

        get base_url, params: {query: "jill@"}
        expect(assigns(:organization_roles).pluck(:user_id)).to match_array([user2.id])

        get "#{base_url}?query=mo"
        expect(assigns(:organization_roles).pluck(:user_id)).to match_array([user2.id])
      end
    end

    describe "new" do
      it "renders the page" do
        get "#{base_url}/new", params: {organization_id: current_organization.to_param}
        expect(response.code).to eq("200")
        expect(response).to render_template :new
      end
    end

    describe "edit" do
      context "organization_role" do
        let(:organization_role) { FactoryBot.create(:organization_role_claimed, organization: current_organization) }
        it "renders the page" do
          get "#{base_url}/#{organization_role.id}/edit", params: {organization_id: current_organization.to_param}
          expect(assigns(:organization_role)).to eq organization_role
          expect(response.code).to eq("200")
          expect(response).to render_template :edit
        end
      end
    end

    describe "update" do
      context "organization_role" do
        context "other valid organization_role" do
          let(:organization_role) { FactoryBot.create(:organization_role_claimed, organization: current_organization, role: "member") }
          let(:organization_role_params) { {role: "admin", user_id: 333} }
          it "updates the role" do
            og_user = organization_role.user
            put "#{base_url}/#{organization_role.id}", params: {organization_role: organization_role_params}
            expect(response).to redirect_to organization_users_path(organization_id: current_organization.to_param)
            expect(flash[:success]).to be_present
            organization_role.reload
            expect(organization_role.role).to eq "admin"
            expect(organization_role.user).to eq og_user
          end
        end
        context "marking self member" do
          let(:organization_role) { current_user.organization_roles.first }
          it "does not update the organization_role" do
            put "#{base_url}/#{organization_role.id}", params: {organization_id: current_organization.to_param, organization_role: {role: "member"}}
            expect(response).to redirect_to organization_users_path(organization_id: current_organization.to_param)
            expect(flash[:error]).to be_present
            organization_role.reload
            expect(organization_role.role).to eq "admin"
            expect(organization_role.user).to eq current_user
          end
        end
      end
    end

    describe "destroy" do
      context "organization_role unclaimed" do
        let(:organization_role) { FactoryBot.create(:organization_role, organization: current_organization, sender: current_user) }
        it "destroys" do
          expect(organization_role.claimed?).to be_falsey
          count = current_organization.remaining_invitation_count
          expect {
            delete "#{base_url}/#{organization_role.id}"
          }.to change(OrganizationRole, :count).by(-1)
          expect(response).to redirect_to organization_users_path(organization_id: current_organization.to_param)
          expect(flash[:success]).to be_present
          current_organization.reload
          expect(current_organization.remaining_invitation_count).to eq(count + 1)
        end
      end
      context "organization_role" do
        context "other valid organization_role" do
          let(:organization_role) { FactoryBot.create(:organization_role_claimed, organization: current_organization, role: "member") }
          it "destroys the organization_role" do
            expect(organization_role.claimed?).to be_truthy
            count = current_organization.remaining_invitation_count
            expect {
              delete "#{base_url}/#{organization_role.id}"
            }.to change(OrganizationRole, :count).by(-1)
            expect(response).to redirect_to organization_users_path(organization_id: current_organization.to_param)
            expect(flash[:success]).to be_present
            current_organization.reload
            expect(current_organization.remaining_invitation_count).to eq(count + 1)
          end
        end
        context "marking self member" do
          let(:organization_role) { current_user.organization_roles.first }
          it "does not destroy" do
            count = current_organization.remaining_invitation_count
            expect {
              delete "#{base_url}/#{organization_role.id}"
            }.to change(OrganizationRole, :count).by(0)
            expect(response).to redirect_to organization_users_path(organization_id: current_organization.to_param)
            expect(flash[:error]).to be_present
            current_organization.reload
            expect(current_organization.remaining_invitation_count).to eq count
          end
        end
      end
    end

    describe "create" do
      before { Sidekiq::Job.clear_all }
      let(:organization_role_params) do
        {
          role: "member",
          invited_email: "bike_email@bike_shop.com"
        }
      end
      context "no email" do
        it "fails" do
          expect {
            post base_url, params: {organization_role: organization_role_params.merge(invited_email: " ")}
          }.to change(OrganizationRole, :count).by(0)
          expect(assigns(:organization_role).errors.full_messages).to be_present
        end
      end
      context "available invitations" do
        it "creates organization_role, reduces invitation tokens by 1" do
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(current_organization.remaining_invitation_count).to eq 4
            expect(User.count).to eq 2
            expect {
              post base_url, params: {organization_role: organization_role_params}
            }.to change(OrganizationRole, :count).by(1)
            expect(response).to redirect_to organization_users_path(organization_id: current_organization.to_param)
            expect(flash[:success]).to be_present
            current_organization.reload
            expect(current_organization.remaining_invitation_count).to eq 3
            organization_role = OrganizationRole.last
            expect(organization_role.role).to eq "member"
            expect(organization_role.sender).to eq current_user
            expect(organization_role.invited_email).to eq "bike_email@bike_shop.com"
            expect(organization_role.claimed?).to be_falsey
            expect(organization_role.email_invitation_sent_at).to be_present
            expect(current_organization.sent_invitation_count).to eq 2
            expect(User.count).to eq 2 # make sure we aren't creating an extra user (aka not doing passwordless users)
            expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          end
        end
      end
      context "no available invitations" do
        let(:current_organization) { FactoryBot.create(:organization, available_invitation_count: 1) }
        it "does not create a new organization_role" do
          expect {
            post base_url, params: {organization_role: organization_role_params}
          }.to change(OrganizationRole, :count).by(0)
          expect(response).to redirect_to organization_users_path(organization_id: current_organization.to_param)
          expect(flash[:error]).to be_present
        end
      end
      context "restrict_invitations? is false" do
        let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], passwordless_user_domain: "example.gov", available_invitation_count: 1) }
        it "just creates the user" do
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(current_organization.remaining_invitation_count).to eq 0
            expect(current_organization.restrict_invitations?).to be_falsey
            expect {
              post base_url, params: {organization_role: organization_role_params}
            }.to change(OrganizationRole, :count).by 1
            expect(ActionMailer::Base.deliveries.count).to eq 0 # Because passwordless users
          end
        end
      end
      context "multiple invitations" do
        let(:multiple_emails_invited) { %w[stuff@stuff.com stuff@stuff2.com stuff@stuff.com stuff3@stuff.com stuff4@stuff.com stuff4@stuff.com stuff4@stuff.com] }
        let(:target_invited_emails) { %w[stuff@stuff.com stuff@stuff2.com stuff3@stuff.com stuff4@stuff.com] + [current_user.email] }
        it "invites, dedupes" do
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(current_organization.remaining_invitation_count).to eq 4
            expect {
              post base_url, params: {
                organization_role: organization_role_params,
                multiple_emails_invited: multiple_emails_invited.join("\n ") + "\n"
              }
            }.to change(OrganizationRole, :count).by 4
            expect(current_organization.remaining_invitation_count).to eq 0
            expect(current_organization.sent_invitation_count).to eq 5
            expect(current_organization.organization_roles.pluck(:invited_email)).to match_array(target_invited_emails)
            expect(current_organization.users.count).to eq 1
            expect(ActionMailer::Base.deliveries.empty?).to be_falsey
          end
        end
        context "more than available" do
          let(:current_organization) { FactoryBot.create(:organization, available_invitation_count: 3) }
          it "renders error, doesn't create any" do
            Sidekiq::Testing.inline! do
              ActionMailer::Base.deliveries = []
              expect {
                post base_url, params: {
                  organization_role: organization_role_params,
                  multiple_emails_invited: multiple_emails_invited.join("\n")
                }
              }.to_not change(OrganizationRole, :count)
              expect(ActionMailer::Base.deliveries.count).to eq 0
            end
          end
          context "restrict_invitations? is false" do
            let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], passwordless_user_domain: "example.gov", available_invitation_count: 1) }
            it "creates organization_roles" do
              Sidekiq::Testing.inline! do
                ActionMailer::Base.deliveries = []
                expect(current_organization.remaining_invitation_count).to eq 0
                expect {
                  post base_url, params: {
                    organization_role: organization_role_params,
                    multiple_emails_invited: multiple_emails_invited.join("\n ") + "\n"
                  }
                }.to change(OrganizationRole, :count).by 4
                expect(current_organization.organization_roles.pluck(:invited_email)).to match_array(target_invited_emails)
                expect(current_organization.users.count).to eq 5
                expect(ActionMailer::Base.deliveries.empty?).to be_truthy
              end
            end
          end
        end
        context "auto_passwordless_users" do
          let(:organization_feature) { FactoryBot.create(:organization_feature, amount_cents: 0, feature_slugs: ["passwordless_users"]) }
          let!(:invoice) { FactoryBot.create(:invoice_paid, amount_due: 0, organization: current_organization) }
          it "invites whatever" do
            # We have to actually assign the invoice here because organization_role creation bumps the organization -
            # and the organization needs to have the organization feature after the first organization_role is created
            Sidekiq::Testing.inline! do
              invoice.update(organization_feature_ids: [organization_feature.id])
              expect(current_organization.reload.enabled_feature_slugs).to eq(["passwordless_users"])

              ActionMailer::Base.deliveries = []
              expect(current_organization.remaining_invitation_count).to eq 4
              expect(current_organization.users.count).to eq 1
              expect(current_organization.users.confirmed.count).to eq 1

              expect {
                post base_url, params: {
                  organization_role: organization_role_params,
                  multiple_emails_invited: multiple_emails_invited.join("\n ") + "\n"
                }
              }.to change(OrganizationRole, :count).by 4

              expect(current_organization.remaining_invitation_count).to eq 0
              expect(current_organization.sent_invitation_count).to eq 5
              expect(current_organization.organization_roles.pluck(:invited_email)).to match_array(target_invited_emails)

              expect(current_organization.users.count).to eq 5
              expect(current_organization.users.confirmed.count).to eq 5
              expect(current_organization.users.pluck(:email)).to match_array(target_invited_emails)
              expect(ActionMailer::Base.deliveries.empty?).to be_truthy
            end
          end
        end
      end
    end
  end
end
