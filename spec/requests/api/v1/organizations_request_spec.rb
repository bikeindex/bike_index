require "rails_helper"

RSpec.describe Api::V1::OrganizationsController, type: :request do
  base_url = "/api/v1/organizations"

  describe "show" do
    let(:organization) { FactoryBot.create(:organization) }
    it "returns unauthorized unless organizations api token present" do
      get "#{base_url}/#{organization.slug}", params: { format: :json }
      expect(response.code).to eq("401")
    end

    it "returns the organization info if the token is present" do
      options = { access_token: ENV["ORGANIZATIONS_API_ACCESS_TOKEN"] }
      get "#{base_url}/#{organization.slug}", params: options.merge(format: :json)
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)
      expect(result["name"]).to eq(organization.name)
      expect(result["can_add_bikes"]).to be_falsey
    end

    it "returns the organization info if the org token is present" do
      options = { access_token: organization.access_token }
      get "#{base_url}/#{organization.to_param}", params: options.merge(format: :json)
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)
      expect(json_result["name"]).to eq(organization.name)
      expect(json_result["can_add_bikes"]).to be_falsey
    end

    it "404s if the organization doesn't exist" do
      body = { access_token: ENV["ORGANIZATIONS_API_ACCESS_TOKEN"] }
      get "#{base_url}/fake_organization_slug", params: body.merge(format: :json)
      expect(response).to redirect_to(api_v1_not_found_url)
    end

    context "numeric id, has_bike_stickers" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user, :in_chicago, kind: "bike_shop") }
      let!(:organization_regional_parent) { FactoryBot.create(:organization_with_paid_features, :in_chicago, regional_ids: [organization.id], enabled_feature_slugs: %w[regional_bike_counts bike_stickers]) }
      let(:target) do
        {
          id: organization.id,
          name: organization.name,
          slug: organization.slug,
          can_add_bikes: true,
          lightspeed_register_with_phone: false,
          manual_pos_kind: nil,
          has_bike_stickers: true
        }
      end
      it "returns expected hash" do
        organization.reload
        expect(organization.regional_parents.pluck(:id)).to eq([organization_regional_parent.id])
        expect(organization_regional_parent.enabled?("bike_stickers")).to be_truthy
        organization.update_attributes(updated_at: Time.current)
        expect(organization.is_paid).to be_falsey
        # Obviously, this is the long way of getting here - could've just enabled bike_stickers directly on org
        # but it's worth including here because this is a place we care about it
        expect(organization.enabled?("bike_stickers")).to be_truthy

        options = { access_token: ENV["ORGANIZATIONS_API_ACCESS_TOKEN"] }
        get "#{base_url}/#{organization.id}", params: options.merge(format: :json)
        expect(response.code).to eq("200")
        expect(json_result).to eq target.as_json
      end
    end
  end

  describe "update manual pos kind" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user, lightspeed_register_with_phone: true) }
    let(:update_params) { { manual_pos_kind: "lightspeed_pos", access_token: organization.access_token } }
    let(:target) do
      {
        id: organization.id,
        name: organization.name,
        slug: organization.slug,
        can_add_bikes: true,
        lightspeed_register_with_phone: true,
        manual_pos_kind: "lightspeed_pos",
        has_bike_stickers: false
      }
    end
    it "updates the manual POS kind for the organization" do
      expect do
        put "#{base_url}/#{organization.to_param}", params: update_params.to_json, headers: json_headers
      end.to change(UpdateOrganizationPosKindWorker.jobs, :count).by(1)
      expect(response.code).to eq("200")
      expect(json_result).to eq target.as_json
      organization.reload
      expect(organization.manual_pos_kind).to eq "lightspeed_pos"
    end
    context "broken pos" do
      include_context :test_csrf_token
      it "updates" do
        Sidekiq::Worker.clear_all
        expect(organization).to be_present
        Sidekiq::Testing.inline! do
          put "#{base_url}/#{organization.id}", params: update_params.merge(organization_id: organization.id, manual_pos_kind: "broken_lightspeed_pos").to_json,
              headers: json_headers
        end
        expect(response.code).to eq("200")
        expect(json_result).to eq target.merge(manual_pos_kind: "broken_lightspeed_pos").as_json
        organization.reload
        expect(organization.manual_pos_kind).to eq "broken_lightspeed_pos"
        expect(organization.pos_kind).to eq "broken_lightspeed_pos"
        expect(organization.broken_pos?).to be_truthy
        expect(Organization.broken_pos.pluck(:id)).to eq([organization.id])
      end
    end
    context "no_pos" do
      let(:organization) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos") }
      let(:target_with_no_pos) { target.merge(can_add_bikes: false, lightspeed_register_with_phone: false, manual_pos_kind: nil) }
      it "removes" do
        expect(organization.manual_pos_kind).to eq "lightspeed_pos"
        expect do
          put "#{base_url}/#{organization.id}", params: update_params.merge(organization_id: organization.id, manual_pos_kind: "no_pos").to_json,
              headers: json_headers
        end.to change(UpdateOrganizationPosKindWorker.jobs, :count).by(1)
        expect(response.code).to eq("200")
        expect(json_result).to eq target_with_no_pos.as_json
        organization.reload
        expect(organization.manual_pos_kind).to be_blank
      end
    end
    context "not valid pos_kind" do
      it "406s" do
        expect do
          put "#{base_url}/#{organization.to_param}", params: update_params.merge(manual_pos_kind: "party").to_json, headers: json_headers
        end.to_not change(UpdateOrganizationPosKindWorker.jobs, :count)
        expect(response.code).to eq("406")
        organization.reload
        expect(organization.manual_pos_kind).to be_blank
      end
    end
    context "organization not found" do
      it "404s" do
        expect do
          put "#{base_url}/32891838283", params: { manual_pos_kind: "lightspeed_pos", access_token: "xxxxx" }.to_json, headers: json_headers
        end.to_not change(UpdateOrganizationPosKindWorker.jobs, :count)
        redirect_to(api_v1_not_found_url)
      end
    end
    context "not organization access_token" do
      it "401s" do
        expect do
          put "#{base_url}/#{organization.to_param}", params: update_params.merge(access_token: "vvvvvvvvv").to_json, headers: json_headers
        end.to_not change(UpdateOrganizationPosKindWorker.jobs, :count)
        expect(response.code).to eq("401")
        organization.reload
        expect(organization.manual_pos_kind).to be_blank
      end
    end
  end
end
