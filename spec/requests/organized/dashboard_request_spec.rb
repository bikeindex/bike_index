require "rails_helper"

RSpec.describe Organized::BaseController, type: :request do
  describe "#root" do
    context "not an ambassador organization" do
      include_context :request_spec_logged_in_as_organization_member

      it "redirects to the bikes page" do
        get "/o/#{current_organization.to_param}"
        expect(response).to redirect_to(organization_bikes_path(organization_id: current_organization.to_param))
        get "/user_root_url_redirect"
        expect(response).to redirect_to(organization_root_path(organization_id: current_organization.to_param))
      end
    end

    context "viewing an ambassador organization" do
      include_context :request_spec_logged_in_as_ambassador

      it "redirects to the ambassador dashboard" do
        get "/o/#{current_organization.to_param}"
        expect(response).to redirect_to(organization_ambassador_dashboard_path(organization_id: current_organization.to_param))
        get "/user_root_url_redirect"
        expect(response).to redirect_to(organization_root_path(organization_id: current_organization.to_param))
      end
    end

    context "law enforcement organization" do
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
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership, organization: current_organization, created_at: Time.current - 2.days) }
    # Test the different organizations that have overview_dashboard? truthy
    context "organization with regional_bike_counts" do
      let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["regional_bike_counts"]) }
      it "renders" do
        current_organization.reload
        expect(current_organization.overview_dashboard?).to be_truthy
        get "/o/#{current_organization.to_param}/dashboard"
        expect(response).to render_template(:index)
        get "/o/#{current_organization.to_param}/dashboard/graph"
        expect(json_result.count).to eq 2
        expect(json_result.first.key?("data")).to be_truthy
      end
    end
    context "organization regional parent" do
      let(:current_organization) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius: 50) }
      let!(:organization_child1) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius: 3, parent_organization: current_organization) }
      let!(:bike) { FactoryBot.create(:bike_organized, organization: organization_child1) }
      it "does not rendern" do
        current_organization.update(updated_at: Time.current)
        current_organization.reload
        expect(current_organization.parent?).to be_truthy
        expect(current_organization.overview_dashboard?).to be_falsey
        get "/o/#{current_organization.to_param}/dashboard"
        expect(response).to redirect_to(organization_bikes_path)
        # ... but it renders if the current_user is superuser
        current_user.update(superuser: true)
        get "/o/#{current_organization.to_param}/dashboard"
        expect(response).to render_template(:index)
      end
    end
    context "organization with claimed_ownerships" do
      let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["claimed_ownerships"], created_at: Time.current - 2.years) }
      let(:claimed_at) { Time.current - 13.months }
      let!(:bike_claimed) { FactoryBot.create(:bike_organized, :with_ownership_claimed, organization: current_organization, claimed_at: claimed_at, created_at: Time.current - 16.months) }
      it "renders" do
        bike_claimed.reload
        expect(bike_claimed.created_at).to be_within(5).of Time.current - 16.months
        expect(bike_claimed.current_ownership.claimed_at).to be_within(5).of claimed_at
        current_organization.reload
        expect(current_organization.overview_dashboard?).to be_truthy
        get "/o/#{current_organization.to_param}/dashboard"
        expect(response).to render_template(:index)
        expect(assigns(:period)).to eq "year"
        expect(assigns(:bikes_in_organizations).pluck(:id)).to eq([bike.id])
        expect(assigns(:claimed_ownerships).pluck(:id)).to eq([])

        get "/o/#{current_organization.to_param}/dashboard?period=custom&start_time=#{Time.current - 2.years}&end_time=#{Time.current - 1.year}"
        expect(response).to render_template(:index)
        expect(assigns(:period)).to eq "custom"
        expect(assigns(:bikes_in_organizations).pluck(:id)).to eq([bike_claimed.id])
        expect(assigns(:claimed_ownerships).pluck(:id)).to eq([bike_claimed.current_ownership.id])

        # 14months - current
        get "/o/#{current_organization.to_param}/dashboard?period=custom&start_time=#{Time.current - 14.months}"
        expect(response).to render_template(:index)
        expect(assigns(:period)).to eq "custom"
        expect(assigns(:bikes_in_organizations).pluck(:id)).to eq([bike.id])
        expect(assigns(:claimed_ownerships).pluck(:id)).to eq([bike_claimed.current_ownership.id])
        expect(assigns(:end_time)).to be_within(5).of Time.current
      end
    end
  end
end
