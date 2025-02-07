require "rails_helper"

RSpec.describe Organized::BaseController, type: :request do
  describe "#root" do
    context "not an ambassador organization" do
      include_context :request_spec_logged_in_as_organization_user

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
      include_context :request_spec_logged_in_as_organization_user
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
    include_context :request_spec_logged_in_as_organization_user
    let!(:bike) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: current_organization, created_at: Time.current - 2.days) }
    # Test the different organizations that have overview_dashboard? truthy
    context "organization with regional_bike_counts" do
      let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["regional_bike_counts"]) }
      it "renders" do
        current_organization.reload
        expect(current_organization.overview_dashboard?).to be_truthy
        get "/o/#{current_organization.to_param}/dashboard"
        expect(response).to render_template(:child_and_regional)
      end
    end
    context "organization regional parent" do
      let(:current_organization) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius_miles: 50) }
      let!(:organization_child1) { FactoryBot.create(:organization, kind: "law_enforcement", search_radius_miles: 3, parent_organization: current_organization) }
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization_child1) }
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
        expect(response).to render_template(:child_and_regional)
      end
    end
    context "organization with claimed_ownerships" do
      let(:current_organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["claimed_ownerships"], created_at: Time.current - 2.years) }
      let(:claimed_at) { Time.current - 13.months }
      let!(:bike_claimed) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: current_organization, claimed_at: claimed_at, created_at: Time.current - 16.months) }
      it "renders" do
        bike_claimed.reload
        expect(bike_claimed.created_at).to be_within(5).of Time.current - 16.months
        expect(bike_claimed.current_ownership.claimed_at).to be_within(5).of claimed_at
        current_organization.reload
        expect(current_organization.overview_dashboard?).to be_truthy
        get "/o/#{current_organization.to_param}/dashboard"
        expect(response).to render_template(:child_and_regional)
        expect(assigns(:period)).to eq "year"
        expect(assigns(:bikes_in_organizations).pluck(:id)).to eq([bike.id])
        expect(assigns(:claimed_ownerships).pluck(:id)).to eq([])

        get "/o/#{current_organization.to_param}/dashboard?period=custom&start_time=#{Time.current - 2.years}&end_time=#{Time.current - 1.year}"
        expect(response).to render_template(:child_and_regional)
        expect(assigns(:period)).to eq "custom"
        expect(assigns(:bikes_in_organizations).pluck(:id)).to eq([bike_claimed.id])
        expect(assigns(:claimed_ownerships).pluck(:id)).to eq([bike_claimed.current_ownership.id])

        # 14months - current
        get "/o/#{current_organization.to_param}/dashboard?period=custom&start_time=#{Time.current - 14.months}"
        expect(response).to render_template(:child_and_regional)
        expect(assigns(:period)).to eq "custom"
        expect(assigns(:bikes_in_organizations).pluck(:id)).to eq([bike.id])
        expect(assigns(:claimed_ownerships).pluck(:id)).to eq([bike_claimed.current_ownership.id])
        expect(assigns(:end_time)).to be_within(5).of Time.current
      end
    end
    context "manufacturer_id" do
      let(:manufacturer) { FactoryBot.create(:manufacturer) }
      let(:current_organization) { FactoryBot.create(:organization, manufacturer_id: manufacturer.id) }
      it "redirects" do
        expect(current_organization.reload.official_manufacturer?).to be_falsey
        expect(current_organization.overview_dashboard?).to be_falsey
        get "/o/#{current_organization.to_param}/dashboard"
        expect(response).to redirect_to(organization_bikes_path)
      end
      context "with official_manufacturer" do
        let(:current_organization) { FactoryBot.create(:organization_with_organization_features, manufacturer_id: manufacturer.id, enabled_feature_slugs: ["official_manufacturer"]) }
        it "renders" do
          expect(manufacturer.reload.official_organization&.id).to eq current_organization.id
          expect(current_organization.reload.invoices.active.count).to eq 1
          expect(current_organization.official_manufacturer?).to be_truthy
          expect(current_organization.overview_dashboard?).to be_truthy
          expect(OrganizationDisplayer.bike_shop_display_integration_alert?(current_organization)).to be_falsey
          get "/o/#{current_organization.to_param}/dashboard"
          expect(response).to render_template(:manufacturer)
          expect(assigns(:period)).to eq "year"
          get "/o/#{current_organization.to_param}/dashboard?period=all"
          # Official manufacturers start at 2017
          expect(assigns(:start_time)).to be_within(1.day).of Time.parse("2017-1-1")
        end
      end
    end
  end
end
