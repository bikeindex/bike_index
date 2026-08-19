require "rails_helper"

RSpec.describe MyAccounts::OrganizationRolesController, type: :request do
  let(:base_url) { "/my_account/organization_roles" }

  describe "update" do
    include_context :request_spec_logged_in_as_user
    let!(:organization_roles) { Array.new(3) { FactoryBot.create(:organization_role_claimed, user: current_user) } }

    it "reorders the user's roles" do
      expect(OrganizationRole.ordered_for(current_user).pluck(:id)).to eq organization_roles.map(&:id)
      patch "#{base_url}/#{organization_roles.last.id}", params: {position: 0}
      expect(response).to be_ok
      expect(OrganizationRole.ordered_for(current_user).pluck(:id))
        .to eq([organization_roles[2].id, organization_roles[0].id, organization_roles[1].id])
    end

    context "another user's role" do
      let!(:other_organization_role) { FactoryBot.create(:organization_role_claimed) }

      it "doesn't reorder it" do
        patch "#{base_url}/#{other_organization_role.id}", params: {position: 0}
        expect(response).to be_not_found
        expect(other_organization_role.reload.priority).to eq 0
      end
    end
  end

  describe "destroy" do
    include_context :request_spec_logged_in_as_user
    let(:organization) { FactoryBot.create(:organization, short_name: "Bike Coop") }
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed, organization:, user: current_user, role:) }
    let(:role) { "member" }

    it "leaves the organization" do
      expect {
        delete "#{base_url}/#{organization_role.id}"
      }.to change(OrganizationRole, :count).by(-1)
      expect(response).to redirect_to edit_my_account_url(edit_template: "organization_roles")
      expect(flash[:success]).to match("Bike Coop")
    end

    context "admin of the organization" do
      let(:role) { "admin" }

      it "doesn't leave" do
        expect {
          delete "#{base_url}/#{organization_role.id}"
        }.to_not change(OrganizationRole, :count)
        expect(flash[:error]).to match("Bike Coop")
      end
    end

    context "another user's role" do
      let!(:other_organization_role) { FactoryBot.create(:organization_role_claimed) }

      it "doesn't leave it" do
        expect {
          delete "#{base_url}/#{other_organization_role.id}"
        }.to_not change(OrganizationRole, :count)
        expect(response).to be_not_found
      end
    end
  end

  context "not logged in" do
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed) }

    it "redirects" do
      patch "#{base_url}/#{organization_role.id}", params: {position: 1}
      expect(response).to redirect_to(/session\/new/)
      expect(organization_role.reload.priority).to eq 0
    end
  end
end
