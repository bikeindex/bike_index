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
        expect(json_result).to match_hash_indifferently {id: current_user.id.to_s, bike_ids: []}
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
