require "spec_helper"

describe IntegrationsController do
  let!(:omniauth_facebook_mock) do
    OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new("provider" => "facebook",
                                                                  "uid" => "64901670",
                                                                  "info" => {
                                                                    "nickname" => "foo.user.5",
                                                                    "email" => "foo.user@gmail.com",
                                                                    "name" => "foo user",
                                                                    "first_name" => "foo",
                                                                    "last_name" => "user",
                                                                    "image" => "http://graph.facebook.com/64901670/picture?type=square",
                                                                    "urls" => {
                                                                      "Facebook" => "http://www.facebook.com/foo.user.5",
                                                                    },
                                                                    "verified" => true,
                                                                  },
                                                                  "credentials" => {
                                                                    "token" => "CAAGW44SIv5sBACqokzRSPaAhh3xiQntB8GD6oRKHToSLWFzz4kv32tJUpK2aZCg3pdzyUNODKjtvXdJyMqCnyZCqPgJvluOK08sbDgRXgQ5oIggVl2pxnokDD09kF1xkQIyUhTI55sUyxOkjKo",
                                                                    "expires_at" => 1373982961,
                                                                    "expires" => true,
                                                                  },
                                                                  "extra" => {
                                                                    "raw_info" => {
                                                                      "id" => "64901670",
                                                                      "name" => "foo user",
                                                                      "first_name" => "foo",
                                                                      "last_name" => "user",
                                                                      "link" => "http://www.facebook.com/foo.user.5",
                                                                      "username" => "foo.user.5",
                                                                      "gender" => "male",
                                                                      "email" => "foo.user@gmail.com",
                                                                      "timezone" => -5,
                                                                      "locale" => "en_US",
                                                                      "verified" => true,
                                                                      "updated_time" => "2012-08-06T23:32:31+0000",
                                                                    },
                                                                  })
  end
  describe "create" do
    context "when there is no user" do
      it "creates an integration" do
        request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:facebook]
        expect do
          post :create
        end.to change(Integration, :count).by(1)
        expect(response.code).to eq("302")
        user = User.last
        expect(User.from_auth(cookies.signed[:auth])).to eq(user)
      end
    end

    describe "when there is a user" do
      let!(:user) { FactoryBot.create(:user_confirmed, email: OmniAuth.config.mock_auth.dig(:facebook, :info, :email)) }
      before { request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:facebook] }

      it "creates a new integration given a refresh token and access token" do
        expect do
          get :create, access_token: "123456", expires_in: "3920",
                       token_type: "Bearer", refresh_token: "1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI"
          expect(flash[:success]).to be_present
          expect(response).to redirect_to(user_home_url)
        end.to change(Integration, :count).by 1
      end

      context "user is already signed in" do
        before { set_current_user(user) }
        it "skips" do
          expect do
            get :create, access_token: "123456", expires_in: "3920",
                         token_type: "Bearer", refresh_token: "1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI"
          end.to change(Integration, :count).by 0
          expect(response).to redirect_to(user_home_url)
        end
      end
    end
  end

  describe "failure" do
    it "renders sessions new with a flash" do
      get :integrations_controller_creation_error, message: "csrf_detected", strategy: "facebook"
      expect(flash[:error]).to match("email us at contact@bikeindex.org")
      expect(response).to redirect_to new_session_path
    end
  end
end
