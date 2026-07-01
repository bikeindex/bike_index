require "rails_helper"

RSpec.describe SamlController, type: :request do
  let(:sp_cert) { File.read(Rails.root.join("spec/fixtures/saml/sp_cert.pem")) }
  let(:sp_key) { File.read(Rails.root.join("spec/fixtures/saml/sp_key.pem")) }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso") }

  around do |example|
    original = ENV.values_at("SAML_SP_CERTIFICATE", "SAML_SP_PRIVATE_KEY", "BASE_URL")
    ENV["SAML_SP_CERTIFICATE"] = sp_cert
    ENV["SAML_SP_PRIVATE_KEY"] = sp_key
    ENV["BASE_URL"] = "https://bikeindex.org"
    example.run
    ENV["SAML_SP_CERTIFICATE"], ENV["SAML_SP_PRIVATE_KEY"], ENV["BASE_URL"] = original
  end

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

  describe "GET /sso (org-slug entry)" do
    it "renders the entry form" do
      get "/sso"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("org_slug")
    end

    context "slug for a configured org" do
      let!(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled, organization:) }
      it "forwards to init" do
        get "/sso", params: {org_slug: organization.to_param}
        expect(response).to redirect_to saml_init_path(org_slug: organization.to_param)
      end
    end

    context "slug for an unconfigured org" do
      it "re-renders with an error" do
        get "/sso", params: {org_slug: organization.to_param}
        expect(response).to have_http_status(:ok)
        expect(flash.now[:error]).to be_present
      end
    end
  end
end
