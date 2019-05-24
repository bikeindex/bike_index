require "spec_helper"

describe Organized::BaseController, type: :controller do
  describe "#root" do
    context "if not viewing an ambassador organization" do
      include_context :logged_in_as_organization_member

      it "redirects to the bikes page" do
        get :root, organization_id: organization.to_param
        expect(response).to redirect_to(organization_bikes_path)
      end
    end

    context "if viewing an ambassador organization" do
      include_context :logged_in_as_ambassador

      it "redirects to the ambassador dashboard" do
        get :root, organization_id: organization.to_param
        expect(response).to redirect_to(organization_ambassador_dashboard_index_path)
      end
    end
  end
end
