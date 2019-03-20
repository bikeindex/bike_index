require "spec_helper"

describe "Oauth::AuthorizationsController" do
  include_context :existing_doorkeeper_app
  before { expect(doorkeeper_app).to be_present }
  let(:scope) { "read_bikes+read_user" }
  let(:authorization_url) { "/oauth/authorize?redirect_uri=#{CGI.escape(doorkeeper_app.redirect_uri)}&client_id=#{doorkeeper_app.uid}&response_type=code&scope=#{scope}" }

  context "no current user present" do
    it "redirects to sign in" do
      get authorization_url
      expect(response).to redirect_to new_session_url
      expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
      expect(session[:partner]).to be_nil
    end
    context "partner parameter" do
      it "redirects to sign in with the partners parameter included" do
        get "#{authorization_url}&partner=bikehub"
        expect(response).to redirect_to new_session_url
        expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
        expect(session[:partner]).to eq "bikehub"
      end
    end
  end

  context "current user present" do
    let!(:user_subject) { FactoryBot.create(:user_confirmed) }
    # Stubbing finding user via cookies because I'm not sure how to set cookies in request spec right now :/
    # TODO: Rails 5 update maybe...
    before { allow(User).to receive(:from_auth) { user_subject } } # Stubbing user lookup
    it "renders" do
      get authorization_url
      expect(response.code).to eq("200")
      expect(response).to render_template(:new)
    end

    context "internal app" do
      before { doorkeeper_app.update_attributes(is_internal: true) }
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
      let!(:user_subject) { FactoryBot.create(:user) }
      it "redirects" do
        get authorization_url
        # This will redirect to please_confirm_email_users_path after new_session realizes an unconfirmed user is present
        expect(response).to redirect_to new_session_path
      end
      context "with unconfirmed scope" do
        let(:scope) { "read_bikes+read_user+unconfirmed" }
        it "renders" do
          fail
          expect(user_subject.confirmed?).to be_falsey
          get authorization_url
          expect(response.code).to eq("200")
          expect(response).to render_template(:new)
        end
      end
    end
  end
end
