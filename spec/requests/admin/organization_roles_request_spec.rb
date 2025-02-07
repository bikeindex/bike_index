require "rails_helper"

RSpec.describe Admin::OrganizationRolesController, type: :request do
  base_url = "/admin/organization_roles/"

  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    let(:organization_role) { FactoryBot.create(:organization_role) }
    it "renders" do
      expect(organization_role).to be_present
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
      expect(organization.organization_roles.count).to eq 0
      post base_url, params: {organization_role: {role: "member", organization_id: organization.id, invited_email: "new_email@stuff.com"}}
      organization.reload
      expect(organization.organization_roles.count).to eq 1
      organization_role = OrganizationRole.last
      expect(organization_role.invited_email).to eq "new_email@stuff.com"
      expect(organization_role.claimed?).to be_falsey
      expect(organization_role.sender).to eq current_user
    end
    context "user present" do
      let!(:existing_user) { FactoryBot.create(:user_confirmed, email: "somebody@stuff.com") }
      it "associates and claims" do
        expect(existing_user.organization_roles.count).to eq 0
        ActionMailer::Base.deliveries = []
        Sidekiq::Worker.clear_all
        expect {
          post base_url, params: {organization_role: {role: "member", organization_id: organization.id, invited_email: "somebody@stuff.com"}}
        }.to change(OrganizationRole, :count).by 1
        expect(organization.organization_roles.count).to eq 1
        existing_user.reload
        organization_role = OrganizationRole.last
        expect(ProcessOrganizationRoleWorker.jobs.count).to eq 1
        ProcessOrganizationRoleWorker.drain
        organization.reload
        organization_role.reload
        expect(existing_user.organization_roles.count).to eq 1
        expect(organization_role.user).to eq existing_user
        expect(organization_role.sender).to eq current_user
      end
    end
  end
end
