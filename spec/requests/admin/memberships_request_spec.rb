require "rails_helper"

RSpec.describe Admin::MembershipsController, type: :request do
  base_url = "/admin/memberships/"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let(:membership) { FactoryBot.create(:membership) }
    it "renders" do
      expect(membership).to be_present
      get base_url
      expect(response).to render_template :index
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response).to render_template :new
    end
  end

  describe "create" do
    let!(:organization) { FactoryBot.create(:organization) }
    it "creates" do
      expect(organization.memberships.count).to eq 0
      post base_url, params: {membership: {role: "member", organization_id: organization.id, invited_email: "new_email@stuff.com"}}
      organization.reload
      expect(organization.memberships.count).to eq 1
      membership = Membership.last
      expect(membership.invited_email).to eq "new_email@stuff.com"
      expect(membership.claimed?).to be_falsey
      expect(membership.sender).to eq current_user
    end
    context "user present" do
      let!(:existing_user) { FactoryBot.create(:user_confirmed, email: "somebody@stuff.com") }
      it "associates and claims" do
        expect(existing_user.memberships.count).to eq 0
        ActionMailer::Base.deliveries = []
        Sidekiq::Worker.clear_all
        expect {
          post base_url, params: {membership: {role: "member", organization_id: organization.id, invited_email: "somebody@stuff.com"}}
        }.to change(Membership, :count).by 1
        expect(organization.memberships.count).to eq 1
        existing_user.reload
        membership = Membership.last
        expect(ProcessMembershipWorker.jobs.count).to eq 1
        ProcessMembershipWorker.drain
        organization.reload
        membership.reload
        expect(existing_user.memberships.count).to eq 1
        expect(membership.user).to eq existing_user
        expect(membership.sender).to eq current_user
      end
    end
  end
end
