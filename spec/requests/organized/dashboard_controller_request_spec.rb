require "rails_helper"

RSpec.describe Organized::BaseController, type: :request do
  describe "#root" do
    context "if not viewing an ambassador organization" do
      include_context :request_spec_logged_in_as_organization_member

      it "redirects to the bikes page" do
        get "/o/#{current_organization.to_param}"
        expect(response).to redirect_to(organization_bikes_path(organization_id: current_organization.to_param))
        get "/user_root_url_redirect"
        expect(response).to redirect_to(organization_root_path(organization_id: current_organization.to_param))
      end
    end

    context "if viewing an ambassador organization" do
      include_context :request_spec_logged_in_as_ambassador

      it "redirects to the ambassador dashboard" do
        get "/o/#{current_organization.to_param}"
        expect(response).to redirect_to(organization_ambassador_dashboard_path(organization_id: current_organization.to_param))
        get "/user_root_url_redirect"
        expect(response).to redirect_to(organization_root_path(organization_id: current_organization.to_param))
      end
    end

    context "if viewing an law enforcement organization" do
      include_context :request_spec_logged_in_as_organization_member
      let(:current_organization) { FactoryBot.create(:organization, kind: "law_enforcement") }

      it "redirects to the ambassador dashboard" do
        expect(current_user.default_organization.law_enforcement?).to be_truthy
        get "/o/#{current_organization.to_param}"
        expect(response).to redirect_to(organization_bikes_path(organization_id: current_organization.to_param))
        get "/user_root_url_redirect"
        # default_bike_search_path
        expect(response).to redirect_to(bikes_path(stolenness: "all"))
      end
    end
  end

  describe "/dashboard" do
    include_context :request_spec_logged_in_as_organization_member
    it "renders" do
      get "/o/#{current_organization.to_param}/dashboard"
      expect(response).to render_template(:index)
    end
  end
end
