require "rails_helper"

RSpec.describe SessionsController, type: :request do
  describe "create_magic_link" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    it "sends the magic link" do
      expect(current_user.magic_link_token).to be_nil
      ActionMailer::Base.deliveries = []
      Sidekiq::Job.clear_all
      Sidekiq::Testing.inline! do
        post "/session/create_magic_link", params: {email: " #{current_user.email} "}
        expect(ActionMailer::Base.deliveries.count).to eq 1
        mail = ActionMailer::Base.deliveries.last
        expect(mail.subject).to eq("Sign in to Bike Index")
        expect(mail.to).to eq([current_user.email])
        expect(current_user.reload.magic_link_token).not_to be_nil
      end
    end
    context "unknown email" do
      it "redirects to login" do
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          post "/session/create_magic_link", params: {email: "something@stuff.bike"}
          expect(flash[:error]).to be_present
          expect(response).to redirect_to new_user_path
          expect(ActionMailer::Base.deliveries.count).to eq 0
        end
      end
    end
    context "passwordless email" do
      let!(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["passwordless_users"], passwordless_user_domain: "party.edu", available_invitation_count: 1) }
      it "autogenerates" do
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          # Just throw this in here because we don't have anywhere else that tests signup with passwordless_user_domain present...
          expect { post "/session/create_magic_link", params: {email: "somethingcool@ party.edu"} }.to_not change(User, :count)
          expect(current_organization.organization_roles.count).to eq 0
          expect {
            post "/session/create_magic_link", params: {email: "somethingcool@party.edu"}
          }.to change(User, :count).by 1
          expect(current_organization.organization_roles.count).to eq 1
          expect(ActionMailer::Base.deliveries.count).to eq 1
          mail = ActionMailer::Base.deliveries.last
          expect(mail.subject).to eq("Sign in to Bike Index")
          expect(mail.to).to eq(["somethingcool@party.edu"])
          user = User.last
          expect(user.confirmed?).to be_truthy
          expect(user.email).to eq "somethingcool@party.edu"
          expect(user.magic_link_token).to be_present
          organization_role = user.organization_roles.first
          expect(organization_role.organization).to eq current_organization
          expect(organization_role.created_by_magic_link).to be_truthy
          expect(organization_role.sender_id).to be_blank
          expect(organization_role.role).to eq "member"
        end
      end
    end
  end

  describe "create" do
    let(:password) { "example_password2" }
    let!(:user) { FactoryBot.create(:user_confirmed, password: password, password_confirmation: password, banned: banned) }
    let(:banned) { false }
    it "signs in" do
      post "/session", params: {session: {email: user.email, password: password}}
      expect(response).to redirect_to my_account_url
      expect(response.headers["X-Frame-Options"]).to eq "SAMEORIGIN"
      user.reload
      expect(user.last_login_at).to be_within(1.second).of Time.current
    end
    context "unconfirmed" do
      let(:user) { FactoryBot.create(:user, password: password, password_confirmation: password) }
      it "does not sign in" do
        expect(user.reload.confirmed).to be_falsey
        post "/session", params: {session: {email: user.email, password: password}}
        expect(response).to redirect_to please_confirm_email_users_path
        user.reload
        expect(user.last_login_at).to be_within(1.second).of Time.current
        get "/my_account"
        expect(response).to redirect_to please_confirm_email_users_path
      end
    end
    context "banned" do
      let(:banned) { true }
      it "renders" do
        post "/session", params: {session: {email: user.email, password: password}}
        expect(response).to redirect_to new_session_path
        user.reload
        expect(user.last_login_at).to be_blank
      end
    end
  end
end
