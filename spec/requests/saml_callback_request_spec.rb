require "rails_helper"

# End-to-end SP-initiated login: a real /init stores the transaction and hands back a
# RelayState, then a signed assertion (minted in-process, see spec/support/saml_helpers.rb)
# is POSTed to the ACS along with it.
RSpec.describe "SAML SSO login", :saml_env, type: :request do
  let(:domain) { "example.edu" }
  let(:organization) do
    # saml_sso alone - provisioning must not need the passwordless feature granted too
    FactoryBot.create(:organization_with_organization_features,
      enabled_feature_slugs: "saml_sso", user_email_domain: domain)
  end
  let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :enabled, organization:) }
  let(:slug) { organization.to_param }
  let(:settings) { Saml::SettingsBuilder.build(saml_configuration) }
  let(:email) { "newperson@#{domain}" }

  before { saml_configuration } # ensure the config exists before /init

  # Drive a real /init; return the AuthnRequest id to echo back as InResponseTo, plus the
  # RelayState the IdP would hand back to us.
  def initiate_login
    get "/sso/#{slug}/init"
    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    [saml_request_id_from_redirect(location), Rack::Utils.parse_query(URI(location).query)["RelayState"]]
  end

  def post_callback(relay_state: :from_init, **overrides)
    request_id, initiated_relay_state = initiate_login
    params = {audience: settings.sp_entity_id, recipient: settings.assertion_consumer_service_url,
              in_response_to: request_id, issuer: saml_configuration.idp_entity_id, email:}.merge(overrides)
    post "/sso/#{slug}/callback", params: {SAMLResponse: signed_saml_response(**params),
                                           RelayState: (relay_state == :from_init) ? initiated_relay_state : relay_state}
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

      context "existing unconfirmed Bike Index user with the asserted email" do
        let!(:existing) { FactoryBot.create(:user, email:) }
        it "confirms and signs in the user rather than bouncing to confirm-email" do
          expect { post_callback }.not_to change(User, :count)
          expect(SsoIdentity.last.user).to eq existing
          expect(existing.reload.confirmed?).to be true
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

      # The only thing that matters for an IdP that mandates encryption: we can actually
      # decrypt what it sends, and the signature inside still verifies afterwards.
      context "encrypted assertion" do
        it "decrypts with the SP private key and signs in" do
          expect { post_callback(encrypt: true) }.to change(User, :count).by(1)
          expect(SsoIdentity.last.email).to eq email
          expect(signed_in?).to be true
        end

        context "no SP private key provisioned" do
          let(:sp_key) { "" }
          it "is rejected rather than raising" do
            expect { post_callback(encrypt: true) }.not_to change(User, :count)
            expect(response).to redirect_to(new_session_path)
            expect(signed_in?).to be false
          end
        end
      end

      # No resolution path may reach a user: not provisioning, not linking, not a returning identity
      context "asserted email domain not in the org" do
        let(:email) { "outsider@gmail.com" }
        it "does not provision or sign in" do
          expect { post_callback }.not_to change(User, :count)
          expect(response).to redirect_to(new_session_path)
          expect(signed_in?).to be false
        end

        context "an account already exists for the asserted email" do
          let!(:existing) { FactoryBot.create(:user_confirmed, email:) }
          it "does not link or sign in" do
            expect { post_callback }.not_to change(SsoIdentity, :count)
            expect(response).to redirect_to(new_session_path)
            expect(signed_in?).to be false
          end
        end

        context "an identity already links the asserted NameID" do
          let(:name_id) { "stable-idp-uid" }
          let!(:identity) do
            FactoryBot.create(:sso_identity, organization:, provider: "saml", uid: name_id,
              user: FactoryBot.create(:user_confirmed, email:))
          end
          it "does not sign in" do
            post_callback(name_id:)
            expect(response).to redirect_to(new_session_path)
            expect(signed_in?).to be false
          end
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

      # Decrypting must not become a way past signature validation
      context "tampered signature inside an encrypted assertion" do
        let(:forge) { {tamper: true, encrypt: true} }
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
      it "is rejected (no RelayState to bind it to)" do
        saml_response = signed_saml_response(audience: settings.sp_entity_id,
          recipient: settings.assertion_consumer_service_url, in_response_to: "_unsolicited",
          issuer: saml_configuration.idp_entity_id, email:)
        post "/sso/#{slug}/callback", params: {SAMLResponse: saml_response}
        expect(response).to redirect_to(new_session_path)
        expect(signed_in?).to be false
      end
    end

    # The IdP returns the assertion as a cross-site POST, which a SameSite=Lax cookie isn't
    # sent on - so the callback has to work with no session at all.
    context "no session cookie on the callback" do
      it "signs in anyway" do
        request_id, relay_state = initiate_login
        reset! # a fresh browser: no cookie of any kind on the POST
        post "/sso/#{slug}/callback", params: {
          SAMLResponse: signed_saml_response(audience: settings.sp_entity_id,
            recipient: settings.assertion_consumer_service_url, in_response_to: request_id,
            issuer: saml_configuration.idp_entity_id, email:),
          RelayState: relay_state
        }
        expect(response).to have_http_status(:found)
        expect(signed_in?).to be true
      end
    end

    context "replayed assertion" do
      it "is rejected the second time, the token being single use" do
        request_id, relay_state = initiate_login
        saml_response = signed_saml_response(audience: settings.sp_entity_id,
          recipient: settings.assertion_consumer_service_url, in_response_to: request_id,
          issuer: saml_configuration.idp_entity_id, email:)

        post "/sso/#{slug}/callback", params: {SAMLResponse: saml_response, RelayState: relay_state}
        expect(signed_in?).to be true

        reset! # a fresh browser: no cookie of any kind on the POST
        post "/sso/#{slug}/callback", params: {SAMLResponse: saml_response, RelayState: relay_state}
        expect(response).to redirect_to(new_session_path)
        expect(signed_in?).to be false
      end
    end

    context "RelayState for a different organization" do
      let(:other_organization) do
        FactoryBot.create(:organization_with_organization_features,
          enabled_feature_slugs: "saml_sso", user_email_domain: "other.edu")
      end
      it "is rejected" do
        foreign_relay_state = Saml::RequestStore.create(request_id: "_whatever",
          org_slug: other_organization.to_param)
        expect { post_callback(relay_state: foreign_relay_state) }.not_to change(User, :count)
        expect(response).to redirect_to(new_session_path)
        expect(signed_in?).to be false
      end
    end
  end
end
