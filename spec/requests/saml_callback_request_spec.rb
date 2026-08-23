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
  let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :active, organization:) }
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

  def initiate_test_login(test_email: email)
    post "/sso/#{slug}/test_start", params: {email: test_email}
    expect(response).to have_http_status(:found)
    location = response.headers["Location"]
    [saml_request_id_from_redirect(location), Rack::Utils.parse_query(URI(location).query)["RelayState"]]
  end

  def post_callback(relay_state: :from_init, drop_session: false, **overrides)
    request_id, initiated_relay_state = initiate_login
    # Rack::Test sends cookies whatever their SameSite, so a spec that needs the browser's
    # actual behaviour on the IdP's cross-site POST has to withhold the session itself
    cookies.delete(Rails.application.config.session_options[:key]) if drop_session
    params = {audience: settings.sp_entity_id, recipient: settings.assertion_consumer_service_url,
              in_response_to: request_id, issuer: saml_configuration.idp_entity_id, email:}.merge(overrides)
    post "/sso/#{slug}/callback", params: {SAMLResponse: signed_saml_response(**params),
                                           RelayState: (relay_state == :from_init) ? initiated_relay_state : relay_state}
  end

  def post_test_callback(test_email: email, **overrides)
    request_id, relay_state = initiate_test_login(test_email:)
    params = {audience: settings.sp_entity_id, recipient: settings.assertion_consumer_service_url,
              in_response_to: request_id, issuer: saml_configuration.idp_entity_id, email:}.merge(overrides)
    post "/sso/#{slug}/callback", params: {SAMLResponse: signed_saml_response(**params), RelayState: relay_state}
  end

  def signed_in?
    cookies[ControllerHelpers::AUTH_COOKIE_KEY].present?
  end

  def diagnostic_value(label)
    Capybara.string(response.body)
      .find(:xpath, "//dt[normalize-space()=#{label.inspect}]/following-sibling::dd[1]").text.strip
  end

  describe "GET /sso/:org_slug/init" do
    it "redirects to the IdP" do
      get "/sso/#{slug}/init"
      expect(response).to have_http_status(:found)
      expect(response.headers["Location"]).to start_with(saml_configuration.idp_sso_target_url)
      expect(response.headers["Location"]).to include("SAMLRequest=")
    end

    context "configuration inactive" do
      let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, :configured, organization:) }

      it "redirects to the IdP" do
        get "/sso/#{slug}/init"
        expect(response).to have_http_status(:found)
      end
    end
  end

  describe "/sso/:org_slug/test" do
    it "renders the form rather than leaving for the IdP" do
      get "/sso/#{slug}/test"
      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Robots-Tag"]).to eq "noindex, nofollow"
      expect(response.body).to include("SAML configuration test")
      expect(Capybara.string(response.body))
        .to have_css("form[action='/sso/#{slug}/test_start'] input[name=email]")
    end

    describe "POST test_start" do
      before { post "/sso/#{slug}/test_start", params: }

      context "with an email" do
        let(:params) { {email:} }

        it "leaves for the IdP" do
          expect(response).to have_http_status(:found)
          expect(response.headers["Location"]).to start_with(saml_configuration.idp_sso_target_url)
        end
      end

      context "with a blank email" do
        let(:params) { {email: " "} }

        it "re-renders the form, having nothing to compare the assertion against" do
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Enter the email address to sign in with")
          expect(Capybara.string(response.body))
            .to have_css("form[action='/sso/#{slug}/test_start'] input[name=email]")
        end
      end
    end

    context "configuration incomplete" do
      let(:saml_configuration) { FactoryBot.create(:organization_saml_configuration, organization:) }

      it "is not found, for the form or the submission" do
        get "/sso/#{slug}/test"
        expect(response).to have_http_status(:not_found)

        post "/sso/#{slug}/test_start", params: {email:}
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

      context "inactive configuration" do
        before { saml_configuration.update!(active: false) }

        it "accepts an assertion for the organization's domain" do
          expect { post_callback }.to change(User, :count).by(1)
          expect(response).to have_http_status(:found)
          expect(signed_in?).to be true
        end
      end

      # The session that stored return_to is withheld on the IdP's cross-site POST, so the
      # destination has to survive in the RelayState transaction instead
      it "returns the user to where they were headed" do
        get "/session/new", params: {return_to: "/bikes/new"}
        post_callback(drop_session: true)
        expect(response).to redirect_to "/bikes/new"
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

      context "asserted email has no parseable domain" do
        it "does not provision or sign in" do
          expect { post_callback(name_id: "transient-name-id", email_attribute: "unreleased-email") }
            .not_to change(User, :count)
          expect(response).to redirect_to(new_session_path)
          expect(signed_in?).to be false
        end
      end

      context "asserted email has multiple @ characters" do
        let(:email) { "attacker@evil.com@#{domain}" }

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

  # Test mode is the same login, landing on a report of what the IdP sent
  describe "POST /sso/:org_slug/callback in test mode" do
    it "signs up and signs in, reporting the assertion" do
      expect { post_test_callback }.to change(User, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Robots-Tag"]).to eq "noindex, nofollow"
      expect(response.body).to include("You were signed up successfully!")
      expect(diagnostic_value("Account")).to include(email, "created by this login")
      expect(SsoIdentity.last.email).to eq email
      expect(signed_in?).to be true
    end

    context "an account already exists for the asserted email" do
      let!(:existing) { FactoryBot.create(:user_confirmed, email:) }

      it "signs it in, reporting that it has a password of its own" do
        expect { post_test_callback }.not_to change(User, :count)
        expect(response.body).to include("You were signed in successfully!")
        expect(diagnostic_value("Account")).to include(email, "already existed")
        expect(diagnostic_value("Account has a password")).to eq "Yes"
        expect(signed_in?).to be true
      end

      context "the account is passwordless" do
        let!(:existing) { FactoryBot.create(:user_confirmed, email:, passwordless_user: true) }

        it "reports it as having no password of its own" do
          post_test_callback
          expect(diagnostic_value("Account has a password")).to eq "No"
        end
      end
    end

    it "reports that the IdP released an address other than the one entered" do
      post_test_callback(test_email: "someoneelse@#{domain}")
      expect(response).to have_http_status(:ok)
      expect(diagnostic_value("Address entered")).to eq "someoneelse@#{domain}"
      expect(diagnostic_value("Asserted email")).to include "the IdP released a different address"
    end

    it "reports a malformed email without provisioning or signing in" do
      expect { post_test_callback(email: "attacker@evil.com@#{domain}") }.not_to change(User, :count)
      expect(response).to have_http_status(:ok)
      # Capybara rather than the raw body: the copy has an apostrophe, which ERB escapes
      expect(Capybara.string(response.body))
        .to have_content("You couldn't be signed in").and have_content("is not on this organization's SSO domain")
      expect(signed_in?).to be false
    end

    it "does not show assertion fields when signature validation fails" do
      # a different address than the assertion carries, so echoing the form back
      # can't be mistaken for the assertion having been read
      expect { post_test_callback(test_email: "typed@#{domain}", tamper: true) }.not_to change(User, :count)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Invalid SAML Response")
      expect(diagnostic_value("Address entered")).to eq "typed@#{domain}"
      expect(response.body).not_to include(email)
      expect(signed_in?).to be false
    end
  end
end
