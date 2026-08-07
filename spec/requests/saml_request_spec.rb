require "rails_helper"

RSpec.describe SamlController, :saml_env, type: :request do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso") }

  describe "GET /sso/:org_slug/metadata" do
    it "returns SP metadata XML" do
      get "/sso/#{organization.to_param}/metadata"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/samlmetadata+xml"
      expect(Nokogiri::XML(response.body).errors).to be_empty
      expect(response.body).to include("https://bikeindex.org/sso/#{organization.to_param}/metadata") # entityID
      expect(response.body).to include("https://bikeindex.org/sso/#{organization.to_param}/callback") # ACS
      expect(response.body).to include("X509Certificate")
    end

    it "never exposes the SP private key" do
      get "/sso/#{organization.to_param}/metadata"
      expect(response.body).to_not include("PRIVATE KEY")
      expect(response.body).to_not include(sp_key.lines[1].strip)
    end

    context "organization without the saml_sso feature" do
      let(:organization) { FactoryBot.create(:organization) }
      it "is not found" do
        get "/sso/#{organization.to_param}/metadata"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "unknown organization" do
      it "is not found" do
        get "/sso/does-not-exist/metadata"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
