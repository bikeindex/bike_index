require "rails_helper"

RSpec.describe Api::V1::OrganizationsController, type: :controller do
  describe "show" do
    let(:organization) { FactoryBot.create(:organization) }
    it "returns unauthorized unless organizations api token present" do
      get :show, params: { id: organization.slug, format: :json }
      expect(response.code).to eq("401")
    end

    it "returns the organization info if the token is present" do
      options = { id: organization.slug, access_token: ENV["ORGANIZATIONS_API_ACCESS_TOKEN"] }
      get :show, params: options.merge(format: :json)
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)
      expect(result["name"]).to eq(organization.name)
      expect(result["can_add_bikes"]).to be_falsey
    end

    it "returns the organization info if the org token is present" do
      options = { id: organization.slug, access_token: organization.access_token }
      get :show, params: options.merge(format: :json)
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)
      expect(result["name"]).to eq(organization.name)
      expect(result["can_add_bikes"]).to be_falsey
    end

    it "404s if the organization doesn't exist" do
      body = { id: "fake_organization_slug", access_token: ENV["ORGANIZATIONS_API_ACCESS_TOKEN"] }
      get :show, params: body.merge(format: :json)
      expect(response).to redirect_to(api_v1_not_found_url)
    end

    context "numeric id" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      it "returns unauthorized unless organizations api token present" do
        options = { id: organization.id, access_token: ENV["ORGANIZATIONS_API_ACCESS_TOKEN"] }
        get :show, params: options.merge(format: :json)
        expect(response.code).to eq("200")
        result = JSON.parse(response.body)
        expect(result["name"]).to eq(organization.name)
        expect(result["can_add_bikes"]).to be_truthy
        expect(result["id"]).to eq organization.id
      end
    end
  end
end
