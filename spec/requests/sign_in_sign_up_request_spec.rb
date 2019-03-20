require "spec_helper"

describe "Sign in and sign up" do
  include_context :existing_doorkeeper_app
  let(:redirect_uri) { "https://bikehub.com/users/auth/bike_index/callback" }
  let(:scope) { "read_bikes+read_user" }
  let(:base_url) { user_home_url(subdomain: false) }
  let(:authorization_url) { "/oauth/authorize?redirect_uri=#{CGI.escape(redirect_uri)}&client_id=#{doorkeeper_app.uid}&response_type=code&scope=#{scope}" }

  let(:user) { FactoryBot.create(:user_confirmed) }

  describe "sign in" do
    # Unable to test cookies, e.g. remember me, because I'm not sure how to set cookies in request spec right now :/
    # TODO: Rails 5 update maybe...
    it "signs in" do
      post "/session", session: { email: user.email, password: user.password, remember_me: "1" }
      expect(response).to redirect_to base_url
    end
    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      it "renders unconfirmed view" do
        get "/session/new", {}, partner: redirect_uri
        post "/session", session: { email: user.email, password: user.password }
        expect(response).to redirect_to please_confirm_email_users_url
      end
    end
    context "with partner present" do
      before do
        expect(doorkeeper_app).to be_present
        doorkeeper_app.update_attributes(is_internal: true)
      end
      it "redirects" do
        # get authorization_url
        get "#{authorization_url}&partner=bikehub"
        expect(response).to redirect_to new_session_url
        # Post from the session path then, since we're there
        post "/session", session: { email: user.email, password: user.password }
        expect(response).to redirect_to "https://new.bikehub.com/account"
      end
      context "unconfirmed" do
        let(:user) { FactoryBot.create(:user) }
        it "redirects even if not passed partner param, because the redirect_uri" do
          get authorization_url
          # get "#{authorization_url}&partner=bikehub"
          expect(response).to redirect_to new_session_url
          # Post from the session path then, since we're there
          post "/session", partner: "bikehub", session: { email: user.email, password: user.password, remember_me: "1" }
          expect(response).to redirect_to "https://new.bikehub.com/account"
          # And then check revisiting bike index, which should send to please confirm email
          get "/session/new"
          expect(response).to redirect_to please_confirm_email_users_url
        end
      end
    end
    context "existing redirect_uri" do
      it "signs in and redirects"
    end
  end
end
