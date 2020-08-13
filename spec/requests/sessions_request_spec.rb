require "rails_helper"

RSpec.describe SessionsController, type: :request do
  describe "create_magic_link" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    it "sends the magic link" do
      expect(current_user.magic_link_token).to be_nil
      ActionMailer::Base.deliveries = []
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! do
        post "/session/create_magic_link", params: { email: " #{current_user.email} " }
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
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          post "/session/create_magic_link", params: { email: "something@stuff.bike" }
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
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          # Just throw this in here because we don't have anywhere else that tests signup with passwordless_user_domain present...
          expect { post "/session/create_magic_link", params: { email: "somethingcool@ party.edu" } }.to_not change(User, :count)
          expect(current_organization.memberships.count).to eq 0
          expect do
            post "/session/create_magic_link", params: { email: "somethingcool@party.edu" }
          end.to change(User, :count).by 1
          expect(current_organization.memberships.count).to eq 1
          expect(ActionMailer::Base.deliveries.count).to eq 1
          mail = ActionMailer::Base.deliveries.last
          expect(mail.subject).to eq("Sign in to Bike Index")
          expect(mail.to).to eq(["somethingcool@party.edu"])
          user = User.last
          expect(user.confirmed?).to be_truthy
          expect(user.email).to eq "somethingcool@party.edu"
          expect(user.magic_link_token).to be_present
          membership = user.memberships.first
          expect(membership.organization).to eq current_organization
          expect(membership.created_by_magic_link).to be_truthy
          expect(membership.sender_id).to be_blank
          expect(membership.role).to eq "member"
        end
      end
    end
  end
end
