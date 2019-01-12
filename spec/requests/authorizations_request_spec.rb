require "spec_helper"

describe "Oauth::AuthorizationsController" do
  include_context :existing_doorkeeper_app
  before { expect(doorkeeper_app).to be_present }

  context "no current user present" do
    it "redirects to sign in" do
      get "/oauth/authorize", response_type: "code", scope: "read_bikes+read_user",
                              client_id: doorkeeper_app.uid, redirect_uri: doorkeeper_app.redirect_uri
      expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
      expect(session[:partner]).to be_nil
    end
    context "partner parameter" do
      it "redirects to sign in with the partners parameter included" do
        get "/oauth/authorize", response_type: "code", scope: "read_bikes+read_user",
                                client_id: doorkeeper_app.uid, redirect_uri: doorkeeper_app.redirect_uri,
                                partner: "bikehub"
        expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
        expect(response).to redirect_to new_session_url
        expect(session[:partner]).to eq "bikehub"
      end
    end
  end

  context "current user present" do
    let!(:user_subject) { FactoryGirl.create(:user_confirmed) }
    # Stubbing finding user via cookies because I'm not sure how to set cookies in request spec right now :/
    # TODO: Rails 5 update maybe...
    before { allow(User).to receive(:from_auth) { user_subject } } # Stubbing user lookup
    it "renders" do
      get "/oauth/authorize", response_type: "code", scope: "read_bikes+read_user",
                              client_id: doorkeeper_app.uid, redirect_uri: doorkeeper_app.redirect_uri
      expect(response.code).to eq("200")
    end

    # This should work. Need to figure out how to make it work though....
    context "internal app" do
      before { doorkeeper_app.update_attributes(is_internal: true) }
      xit "redirects to redirect uri" do
        get "/oauth/authorize", response_type: "code", scope: "read_bikes+read_user",
                                client_id: doorkeeper_app.uid, redirect_uri: doorkeeper_app.redirect_uri
        expect(response).to redirect_to doorkeeper_app.redirect_uri
      end
    end

    context "unconfirmed user" do
      let!(:user_subject) { FactoryGirl.create(:user) }
      it "redirects" do
        expect(user_subject.confirmed?).to be_falsey
        get "/oauth/authorize", response_type: "code", scope: "read_bikes+read_user",
                                client_id: doorkeeper_app.uid, redirect_uri: doorkeeper_app.redirect_uri
        # This will redirect to please_confirm_email_users_path after new_session realizes an unconfirmed user is present
        expect(response).to redirect_to new_session_path
      end
      context "with unconfirmed scope" do
        it "renders" do
          expect(user_subject.confirmed?).to be_falsey
          get "/oauth/authorize", response_type: "code", scope: "read_bikes+read_user+unconfirmed",
                                  client_id: doorkeeper_app.uid, redirect_uri: doorkeeper_app.redirect_uri
          expect(response.code).to eq("200")
        end
      end
    end
  end
end
