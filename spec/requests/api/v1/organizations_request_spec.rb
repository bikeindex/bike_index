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

    context "numeric id" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      it "returns unauthorized unless organizations api token present" do
        options = { access_token: ENV["ORGANIZATIONS_API_ACCESS_TOKEN"] }
        get "#{base_url}/#{organization.id}", params: options.merge(format: :json)
        expect(response.code).to eq("200")
        expect(json_result["name"]).to eq(organization.name)
        expect(json_result["can_add_bikes"]).to be_truthy
        expect(json_result["id"]).to eq organization.id
      end
    end
  end

  describe "update manual pos kind" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:update_params) { { manual_pos_kind: "lightspeed_pos", access_token: organization.access_token } }
    it "updates the manual POS kind for the organization" do
      expect do
        put "#{base_url}/#{organization.to_param}", params: update_params.to_json, headers: json_headers
      end.to change(UpdateOrganizationPosKindWorker.jobs, :count).by(1)
      expect(response.code).to eq("200")
      expect(json_result["manual_pos_kind"]).to eq "lightspeed_pos"
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
        expect(json_result["manual_pos_kind"]).to eq "broken_lightspeed_pos"
        organization.reload
        expect(organization.manual_pos_kind).to eq "broken_lightspeed_pos"
        expect(organization.pos_kind).to eq "broken_lightspeed_pos"
        expect(organization.broken_pos?).to be_truthy
        expect(Organization.broken_pos.pluck(:id)).to eq([organization.id])
      end
    end
    context "no_pos" do
      let(:organization) { FactoryBot.create(:organization, manual_pos_kind: "lightspeed_pos") }
      it "removes" do
        expect(organization.manual_pos_kind).to eq "lightspeed_pos"
        expect do
          put "#{base_url}/#{organization.id}", params: update_params.merge(organization_id: organization.id, manual_pos_kind: "no_pos").to_json,
              headers: json_headers
        end.to change(UpdateOrganizationPosKindWorker.jobs, :count).by(1)
        expect(response.code).to eq("200")
        expect(json_result["manual_pos_kind"]).to be_blank
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
