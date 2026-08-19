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

    context "on_by_default" do
      it "renumbers the user's roles from 1, and back from 0" do
        patch "#{base_url}/#{organization_roles.first.id}", params: {on_by_default: false}
        expect(response).to be_ok
        expect(OrganizationRole.ordered_for(current_user).pluck(:priority)).to eq([1, 2, 3])

        patch "#{base_url}/#{organization_roles.first.id}", params: {on_by_default: true}
        expect(response).to be_ok
        expect(OrganizationRole.ordered_for(current_user).pluck(:priority)).to eq([0, 1, 2])
      end
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

  context "not logged in" do
    let!(:organization_role) { FactoryBot.create(:organization_role_claimed) }

    it "redirects" do
      patch "#{base_url}/#{organization_role.id}", params: {position: 1}
      expect(response).to redirect_to(/session\/new/)
      expect(organization_role.reload.priority).to eq 0
    end
  end
end
