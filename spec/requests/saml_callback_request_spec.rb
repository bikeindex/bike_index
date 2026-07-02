require "rails_helper"

# End-to-end SP-initiated login: a real /init populates the session, then a signed
# assertion (minted in-process, see spec/support/saml_helpers.rb) is POSTed to the ACS.
RSpec.describe "SAML SSO login", type: :request do
  let(:domain) { "example.edu" }
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features,
      enabled_feature_slugs: %w[saml_sso passwordless_users], passwordless_user_domain: domain)
  end
  let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled, organization:) }
  let(:slug) { organization.to_param }
  let(:settings) { Saml::SettingsBuilder.build(saml_configuration) }
  let(:sp_cert) { File.read(Rails.root.join("spec/fixtures/saml/sp_cert.pem")) }
  let(:sp_key) { File.read(Rails.root.join("spec/fixtures/saml/sp_key.pem")) }
  let(:email) { "newperson@#{domain}" }

  around do |example|
    original = ENV.values_at("SAML_SP_CERTIFICATE", "SAML_SP_PRIVATE_KEY", "BASE_URL")
    ENV["SAML_SP_CERTIFICATE"] = sp_cert
    ENV["SAML_SP_PRIVATE_KEY"] = sp_key
    ENV["BASE_URL"] = "https://bikeindex.org"
    example.run
    ENV["SAML_SP_CERTIFICATE"], ENV["SAML_SP_PRIVATE_KEY"], ENV["BASE_URL"] = original
  end

  before { saml_configuration } # ensure the config exists before /init

  # Drive a real /init so the session carries saml_request_id + saml_org_slug;
  # return the AuthnRequest id to echo back as InResponseTo.
  def initiate_login
    get "/sso/#{slug}/init"
    expect(response).to have_http_status(:found)
    saml_request_id_from_redirect(response.headers["Location"])
  end

  def post_callback(**overrides)
    request_id = initiate_login
    params = {audience: settings.sp_entity_id, recipient: settings.assertion_consumer_service_url,
              in_response_to: request_id, issuer: saml_configuration.idp_entity_id, email:}.merge(overrides)
    post "/sso/#{slug}/callback", params: {SAMLResponse: signed_saml_response(**params)}
  end

  def signed_in?
    cookies[ControllerHelpers::AUTH_COOKIE_KEY].present?
  end

  describe "GET /sso/:org_slug/init" do
    it "redirects to the IdP" do
      get "/sso/#{slug}/init"
      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to start_with(saml_configuration.idp_sso_target_url)
      expect(response.headers["Location"]).to include("SAMLRequest=")
    end

    context "configuration not enabled" do
      let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, organization:) }
      it "is not found" do
        get "/sso/#{slug}/init"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /sso/:org_slug/callback" do
    context "valid assertion" do
      it "provisions and signs in a new user" do
        expect { post_callback }.to change(User, :count).by(1)
        expect(response).to have_http_status(:found)
        identity = SsoIdentity.last
        expect(identity.organization).to eq organization
        expect(identity.provider).to eq "saml"
        expect(identity.email).to eq email
        user = User.find_by(email:)
        expect(identity.user).to eq user
        expect(user.last_login_at).to be_within(5.seconds).of Time.current
        expect(signed_in?).to be true
      end

      context "existing Bike Index user with the asserted email" do
        let!(:existing) { FactoryBot.create(:user_confirmed, email:) }
        it "links the existing user without creating one" do
          expect { post_callback }.not_to change(User, :count)
          expect(SsoIdentity.last.user).to eq existing
          expect(signed_in?).to be true
        end
      end

      context "returning identity (same IdP NameID)" do
        let(:name_id) { "stable-idp-uid" }
        let!(:identity) do
          FactoryBot.create(:sso_identity, organization:, provider: "saml", uid: name_id,
            user: FactoryBot.create(:user_confirmed, email:))
        end
        it "signs in the linked user without creating one" do
          expect { post_callback(name_id:) }.not_to change(User, :count)
          expect(signed_in?).to be true
          expect(identity.reload.last_sign_in_at).to be_present
        end
      end

      context "asserted email domain not in the org" do
        let(:email) { "outsider@gmail.com" }
        it "does not provision or sign in" do
          expect { post_callback }.not_to change(User, :count)
          expect(response).to redirect_to(new_session_path)
          expect(signed_in?).to be false
        end
      end
    end

    context "invalid assertions" do
      shared_examples "rejected" do
        it "does not sign in" do
          expect { post_callback(**forge) }.not_to change(User, :count)
          expect(response).to redirect_to(new_session_path)
          expect(signed_in?).to be false
        end
      end

      context "unsigned assertion" do
        let(:forge) { {sign: false} }
        include_examples "rejected"
      end

      context "tampered signature" do
        let(:forge) { {tamper: true} }
        include_examples "rejected"
      end

      context "InResponseTo mismatch" do
        let(:forge) { {in_response_to: "_not-the-request-id"} }
        include_examples "rejected"
      end

      context "expired NotOnOrAfter" do
        let(:forge) { {not_on_or_after: (Time.current - 1.hour).utc.iso8601} }
        include_examples "rejected"
      end

      context "wrong Audience" do
        let(:forge) { {audience: "https://bikeindex.org/sso/someone-else/metadata"} }
        include_examples "rejected"
      end

      context "cross-tenant Recipient" do
        let(:forge) { {recipient: "https://bikeindex.org/sso/someone-else/callback"} }
        include_examples "rejected"
      end

      context "Issuer mismatch" do
        let(:forge) { {issuer: "https://attacker.example/"} }
        include_examples "rejected"
      end
    end

    context "unsolicited response (no prior init)" do
      it "is rejected (no session binding)" do
        saml_response = signed_saml_response(audience: settings.sp_entity_id,
          recipient: settings.assertion_consumer_service_url, in_response_to: "_unsolicited",
          issuer: saml_configuration.idp_entity_id, email:)
        post "/sso/#{slug}/callback", params: {SAMLResponse: saml_response}
        expect(response).to redirect_to(new_session_path)
        expect(signed_in?).to be false
      end
    end
  end
end
