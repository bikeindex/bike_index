require "rails_helper"

RSpec.describe SamlController, :saml_env, type: :request do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: "saml_sso") }

  describe "GET /sso/:org_slug/metadata" do
    # The entityID is this url, so it has to keep serving metadata itself - and IdP admins
    # paste it into a metadata-url field, since we hand them the same string
    it "serves the same document with and without the .xml extension" do
      get "/sso/#{organization.to_param}/metadata"
      expect(response).to have_http_status(:ok)
      extensionless = response.body

      get "/sso/#{organization.to_param}/metadata.xml"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/xml"
      # the metadata carries a per-request ID, so compare everything else
      expect(response.body.sub(/ID='[^']*'/, "")).to eq extensionless.sub(/ID='[^']*'/, "")
    end

    it "returns SP metadata XML advertising both key uses, and never the private key" do
      get "/sso/#{organization.to_param}/metadata.xml"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/xml"
      document = Nokogiri::XML(response.body)
      expect(document.errors).to be_empty
      expect(response.body).to include("https://bikeindex.org/sso/#{organization.to_param}/metadata") # entityID
      expect(response.body).to include("https://bikeindex.org/sso/#{organization.to_param}/callback") # ACS

      # An IdP that encrypts needs the encryption KeyDescriptor to have a key to encrypt to
      key_uses = document.xpath("//md:KeyDescriptor", "md" => SamlHelpers::MD_NS).map { |el| el["use"] }
      expect(key_uses).to match_array(%w[signing encryption])

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

  describe "GET /sso/:org_slug/sp.crt" do
    it "serves the SP certificate as a download, and never the private key" do
      get "/sso/#{organization.to_param}/sp.crt"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/pem-certificate-chain"
      expect(response.body).to eq sp_cert
      expect(response.body).to_not include("PRIVATE KEY")
    end

    context "without an SP certificate configured" do
      let(:sp_cert) { "" }
      it "is not found" do
        get "/sso/#{organization.to_param}/sp.crt"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "organization without the saml_sso feature" do
      let(:organization) { FactoryBot.create(:organization) }
      it "is not found" do
        get "/sso/#{organization.to_param}/sp.crt"
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
