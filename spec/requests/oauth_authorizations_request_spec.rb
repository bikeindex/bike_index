require "rails_helper"

RSpec.describe Oauth::AuthorizationsController, type: :request do
  include_context :existing_doorkeeper_app
  before { expect(doorkeeper_app).to be_present }
  let(:scope_param) { "scope=read_bikes+read_user" }
  let(:authorization_url) { "/oauth/authorize?redirect_uri=#{CGI.escape(doorkeeper_app.redirect_uri)}&client_id=#{doorkeeper_app.uid}&response_type=code&#{scope_param}" }

  context "no current user present" do
    it "redirects to sign in" do
      get authorization_url
      expect(response).to redirect_to new_session_url
      expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
      expect(session[:partner]).to be_nil
      expect(flash).to be_blank
    end
    # A native app hands OAuth to a webview, then the magic link opens in the phone's browser,
    # which has none of that session — so the authorize URL has to travel in the link itself
    context "signing in with a magic link opened in another browser" do
      let(:user) { FactoryBot.create(:user_confirmed, passwordless_user: true) }

      it "resumes the authorization" do
        get authorization_url
        ActionMailer::Base.deliveries = []
        Sidekiq::Testing.inline! do
          post "/session/identify", params: {session: {email: user.email}}
        end
        emailed_url = ActionMailer::Base.deliveries.last.body.parts.first.decoded[%r{https?://\S+/session/magic_link\S*}]
        expect(emailed_url).to include CGI.escape("client_id=#{doorkeeper_app.uid}")

        reset! # Wipe the session, as opening the link in a different browser does
        get emailed_url
        hidden_fields = Capybara.string(response.body).all("form input[type=hidden]", visible: :all)
          .to_h { |input| [input[:name], input[:value]] }.except("authenticity_token")
        expect(hidden_fields["return_to"]).to match(/#{doorkeeper_app.uid}/)

        post "/session/sign_in_with_magic_link", params: hidden_fields
        expect(response).to redirect_to(/#{doorkeeper_app.uid}/)
      end
    end
    context "partner parameter" do
      it "redirects to sign in with the partners parameter included" do
        get "#{authorization_url}&partner=bikehub"
        expect(response).to redirect_to new_session_url
        expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
        expect(session[:partner]).to eq "bikehub"
        expect(flash).to be_blank
      end
      context "unauthenticated_redirect=signup" do
        it "redirects to sign up with the partners parameter" do
          get "#{authorization_url}&partner=bikehub&unauthenticated_redirect=sign_up"
          expect(response).to redirect_to new_user_url
          expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
          expect(session[:partner]).to eq "bikehub"
          expect(flash).to be_blank
        end
      end
      context "unauthenticated_redirect=no" do
        it "redirects to sign in with the partners parameter" do
          get "#{authorization_url}&partner=bikehub&unauthenticated_redirect=no"
          expect(response).to redirect_to new_session_url
          expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
          expect(session[:partner]).to eq "bikehub"
          expect(flash).to be_blank
        end
      end
    end
  end

  context "current user present" do
    include_context :request_spec_logged_in_as_user

    describe "Authorize redirect" do
      it "renders" do
        get authorization_url
        expect(response.code).to eq("200")
        expect(response).to render_template(:new)
        expect(response.body).to match(/authorize/i)
        expect(response.body).to match(/form action=.\/oauth\/authorize/)
        expect(response.body).to_not include("fbevents.js")
        expect(response.body).to match(/nav class="primary-header-nav"/)
        expect(response.body).to_not include("primary-main-menu")
      end
      context "non-https redirect_uri" do
        before { doorkeeper_app.update(redirect_uri:) }

        context "custom scheme, like a native app" do
          let(:redirect_uri) { "bikeindex://oauth-callback" }
          it "renders without the insecure authorization modal" do
            get authorization_url
            expect(response.code).to eq("200")
            expect(response.body).to_not match("insecure-authorization-modal")
          end
        end

        context "cleartext http" do
          let(:redirect_uri) { "http://app.com" }
          it "renders the insecure authorization modal, its cancel button denying" do
            get authorization_url
            expect(response.code).to eq("200")
            expect(response.body).to match("insecure-authorization-modal")
            # Cancelling has to deny - closing the modal is the documented way to continue anyway
            expect(response.body).to match(/<form[^>]*id="deny-authorization"/)
            expect(response.body).to match(/<button[^>]*form="deny-authorization"/)
          end
        end
      end
      context "no scope" do
        let(:scope_param) { "" }
        it "errors" do
          # We require a scope parameter to be passed
          get authorization_url
          expect(response.code).to eq("400")
          expect(response).to render_template(:error)
          expect(response.body).to match("Missing required parameter: scope")
        end
      end
      context "internal app" do
        before { doorkeeper_app.update(is_internal: true) }
        it "redirects to redirect uri" do
          expect(doorkeeper_app.is_internal).to be_truthy
          get authorization_url
          # Ensure the redirect_uri is correct so we can match correctly.
          expect(doorkeeper_app.redirect_uri).to eq "https://app.com"
          # It redirects to the redirect url plus the code
          expect(response).to redirect_to(/\Ahttps:..app.com\?code=/)
        end
      end
      context "unconfirmed user" do
        let!(:current_user) { FactoryBot.create(:user) }
        it "redirects" do
          get authorization_url
          # This will redirect to please_confirm_email_users_path after new_session realizes an unconfirmed user is present
          expect(response).to redirect_to new_session_path
        end
        context "with unconfirmed scope" do
          let(:scope_param) { "scope=read_bikes+read_user+unconfirmed" }
          it "renders" do
            expect(current_user.confirmed?).to be_falsey
            get authorization_url
            expect(response.code).to eq("200")
            expect(response).to render_template(:new)
          end
        end
      end
    end

    describe "authorization_code flow" do
      it "gets a token and makes an authorized request" do
        expect(current_user.confirmed?).to be_truthy
        expect(Doorkeeper::AccessToken.count).to eq 0
        post "/oauth/authorize?response_type=code&redirect_uri=#{doorkeeper_app.redirect_uri}&client_id=#{doorkeeper_app.uid}&scope=write_bikes+read_bikes"
        auth_code = response.redirect_url[/code=[^&]*/i].gsub(/code=/i, "")
        post "/oauth/token?grant_type=authorization_code&code=#{auth_code}&redirect_uri=#{doorkeeper_app.redirect_uri}&client_id=#{doorkeeper_app.uid}&client_secret=#{doorkeeper_app.secret}&scope=write_bikes+read_bikes"
        expect(Doorkeeper::AccessToken.count).to eq 1
        access_token = Doorkeeper::AccessToken.last
        expect(access_token.reload.acceptable?(nil)).to be_truthy
        expect(access_token.resource_owner_id).to eq current_user.id
        expect(access_token.scopes).to match_array(%w[write_bikes read_bikes])
        expect(access_token.expired?).to be_falsey

        expect(json_result["access_token"]).to eq access_token.token
        expect(json_result["token_type"]).to eq "Bearer"
        expect(json_result["refresh_token"]).to be_present
        refresh_token = json_result["refresh_token"]
        # And then test that you can make an authorized request with the token
        get "/api/v3/me", params: {access_token: access_token.token}, headers: {format: :json}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(json_result).to match_hash_indifferently({id: current_user.id.to_s, bike_ids: []})
        # Then, expire the token
        access_token.update(created_at: Time.current - 3700)
        expect(access_token.reload.expired?).to be_truthy
        # ... And verify that it fails to make a request
        get "/api/v3/me", params: {access_token: access_token.token}, headers: {format: :json}
        expect(response.status).to eq 401
        expect(response.body).to match(/access token expired/i)
        # Refresh the token
        post "/oauth/token?grant_type=refresh_token&client_id=#{doorkeeper_app.uid}&refresh_token=#{refresh_token}"
        expect(Doorkeeper::AccessToken.count).to eq 2
        access_token2 = Doorkeeper::AccessToken.last
        expect(access_token2.expired?).to be_falsey
        expect(access_token2.reload.acceptable?(nil)).to be_truthy
        expect(access_token2.resource_owner_id).to eq current_user.id
        expect(json_result["access_token"]).to eq access_token2.token
        expect(json_result["token_type"]).to eq "Bearer"
        expect(json_result["refresh_token"]).to_not eq refresh_token # Because it's a new refresh token!
        # sanity check, original access token is still expired
        expect(access_token.reload.expired?).to be_truthy
      end

      context "with scopes separated by space (%20)" do
        it "gets a token and makes an authorized request" do
          expect(current_user.confirmed?).to be_truthy
          expect(Doorkeeper::AccessToken.count).to eq 0
          post "/oauth/authorize?response_type=code&redirect_uri=#{doorkeeper_app.redirect_uri}&client_id=#{doorkeeper_app.uid}&scope=write_bikes%20read_bikes"
          auth_code = response.redirect_url[/code=[^&]*/i].gsub(/code=/i, "")
          post "/oauth/token?grant_type=authorization_code&code=#{auth_code}&redirect_uri=#{doorkeeper_app.redirect_uri}&client_id=#{doorkeeper_app.uid}&client_secret=#{doorkeeper_app.secret}&scope=write_bikes%20read_bikes"
          expect(Doorkeeper::AccessToken.count).to eq 1
          access_token = Doorkeeper::AccessToken.last
          expect(access_token.reload.acceptable?(nil)).to be_truthy
          expect(access_token.resource_owner_id).to eq current_user.id
          expect(access_token.scopes).to match_array(%w[write_bikes read_bikes])
        end
      end
    end

    describe "authorization_code flow with PKCE" do
      let(:code_verifier) { "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk" }
      let(:code_challenge) { Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false) }
      let(:code_challenge_method) { "S256" }
      let(:authorize_params) { "response_type=code&redirect_uri=#{doorkeeper_app.redirect_uri}&client_id=#{doorkeeper_app.uid}&scope=read_bikes&code_challenge=#{code_challenge}&code_challenge_method=#{code_challenge_method}" }
      # No client_secret - the point of PKCE is securing public clients, which can't keep one
      let(:token_params) { "grant_type=authorization_code&redirect_uri=#{doorkeeper_app.redirect_uri}&client_id=#{doorkeeper_app.uid}" }
      let(:auth_code) do
        post "/oauth/authorize?#{authorize_params}"
        response.redirect_url[/code=[^&]*/i].gsub(/code=/i, "")
      end

      it "stores the challenge and exchanges the code for a token" do
        expect(Doorkeeper::AccessGrant.find_by(token: auth_code).code_challenge).to eq code_challenge
        post "/oauth/token?#{token_params}&code=#{auth_code}&code_verifier=#{code_verifier}"
        expect(Doorkeeper::AccessToken.count).to eq 1
        expect(json_result["access_token"]).to eq Doorkeeper::AccessToken.last.token
      end

      context "mismatched code_verifier" do
        it "refuses the token" do
          post "/oauth/token?#{token_params}&code=#{auth_code}&code_verifier=#{code_verifier.reverse}"
          expect(response.code).to eq("400")
          expect(json_result["error"]).to eq "invalid_grant"
          expect(Doorkeeper::AccessToken.count).to eq 0
        end
      end

      context "missing code_verifier" do
        it "refuses the token" do
          post "/oauth/token?#{token_params}&code=#{auth_code}"
          expect(response.code).to eq("400")
          expect(json_result["error"]).to eq "invalid_request"
          expect(Doorkeeper::AccessToken.count).to eq 0
        end
      end

      context "code_challenge_method=plain" do
        let(:code_challenge_method) { "plain" }
        let(:code_challenge) { code_verifier }
        it "refuses to authorize" do
          get "/oauth/authorize?#{authorize_params}"
          expect(response.code).to eq("400")
          expect(response).to render_template(:error)
          expect(response.body).to match("code_challenge_method must be S256")
          expect(Doorkeeper::AccessGrant.count).to eq 0
        end
      end
    end

    describe "password flow" do
      it "isn't supported, even with valid credentials" do
        post "/oauth/token?grant_type=password&client_id=#{doorkeeper_app.uid}&client_secret=#{doorkeeper_app.secret}&username=#{CGI.escape(current_user.email)}&password=testthisthing7$&scope=read_bikes"
        expect(response.code).to eq("400")
        expect(json_result["error"]).to eq "unsupported_grant_type"
        expect(Doorkeeper::AccessToken.count).to eq 0
      end
    end

    describe "client_credentials flow" do
      it "gets a token and makes an authorized request" do
        expect(current_user.confirmed?).to be_truthy
        expect(Doorkeeper::AccessToken.count).to eq 0
        post "/oauth/token?grant_type=client_credentials&client_id=#{doorkeeper_app.uid}&client_secret=#{doorkeeper_app.secret}&scope=write_bikes+read_bikes"
        expect(Doorkeeper::AccessToken.count).to eq 1
        access_token = Doorkeeper::AccessToken.last
        expect(access_token.reload.acceptable?(nil)).to be_truthy
        expect(access_token.resource_owner_id).to be_blank
        expect(access_token.scopes).to match_array(%w[write_bikes read_bikes])

        expect(json_result["access_token"]).to eq access_token.token
        expect(json_result["token_type"]).to eq "Bearer"
        expect(json_result["refresh_token"]).to be_blank
        # And then test that you can make an authorized reques with the token
        get "/api/v3/me", params: {access_token: access_token.token}, headers: {format: :json}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(json_result["error"]).to match(/no user.*token/i)
      end
    end
  end
end
