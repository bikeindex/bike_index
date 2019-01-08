require "spec_helper"

# Additional coverage for users sign in and up
describe "Oauth::AuthorizationsController" do
  include_context :existing_doorkeeper_app
  before { expect(doorkeeper_app).to be_present }

  context "no current user present" do
    it "redirects to sign in" do
      get "/oauth/authorize", response_type: "code", scope: "read_bikes+read_user",
                              client_id: doorkeeper_app.uid, redirect_uri: doorkeeper_app.redirect_uri
      expect(session[:return_to]).to match(/#{doorkeeper_app.uid}/)
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
end
