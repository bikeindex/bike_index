require "spec_helper"

describe Organized::BaseController, type: :controller do
  describe "#index" do
    context "if not viewing an ambassador organization" do
      include_context :logged_in_as_organization_member

      it "redirects to the bikes page" do
        organization = user.organizations.first
        get :index, organization_id: organization.to_param
        expect(response).to redirect_to(organization_bikes_path(organization))
      end
    end

    context "if viewing an ambassador organization" do
      include_context :logged_in_as_ambassador

      it "redirects to the ambassador dashboard" do
        ambassador_org = user.organizations.first
        get :index, organization_id: ambassador_org.to_param
        expect(response).to redirect_to(organization_ambassadors_path(ambassador_org))
      end
    end
  end
end
