require "rails_helper"

RSpec.describe IntegrationsController, type: :controller do
  context "facebook" do
    let!(:omniauth_facebook_mock) do
      OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new(
        "provider" => "facebook",
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
        },
      )
    end
    describe "create" do
      before { request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:facebook] }
      context "when there is no user" do
        it "creates an integration" do
          expect do
            post :create
          end.to change(Integration, :count).by(1)
          expect(response.code).to eq("302")
          user = User.last
          expect(User.from_auth(cookies.signed[:auth])).to eq(user)
          expect(user.integrations.count).to eq 1
          expect(user.integrations.first.provider_name).to eq "facebook"
        end
      end

      describe "when there is a user" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: OmniAuth.config.mock_auth.dig(:facebook, :info, :email)) }

        it "creates a new integration given a refresh token and access token" do
          expect do
            get :create, params: { access_token: "123456", expires_in: "3920", token_type: "Bearer", refresh_token: "1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI" }
            expect(flash[:success]).to be_present
            expect(response).to redirect_to(my_account_url)
          end.to change(Integration, :count).by 1
        end

        context "user is already signed in" do
          before { set_current_user(user) }
          it "skips" do
            expect do
              get :create, params: { access_token: "123456", expires_in: "3920", token_type: "Bearer", refresh_token: "1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI" }
            end.to change(Integration, :count).by 0
            expect(response).to redirect_to(my_account_url)
          end
        end
      end
    end
  end

  context "globalid" do
    let!(:omniauth_globalid) do
      OmniAuth.config.mock_auth[:globalid] = OmniAuth::AuthHash.new(
        "provider" => "globalid",
        "uid" => "ef141f5d-2a9f-429d-999f-8bbec78a733a",
        "info" => { "nickname" => "sethherr",
                   "name" => "sethherr",
                   "description" => "Wutup",
                   "image" => "https://prod-identityimages.globalid.net/e7a0596a-2d65-4940-9d4e-9083a8908aba",
                   "location" => "USA",
                   "id_token" => { "sub" => "ef141f5d-2a9f-429d-999f-8bbec78a733a",
                                   "iss" => "https://global.id",
                                   "nonce" => "2bf6ea714346d3699453a0270c0f33e5b034ee2c6ac8d47b",
                                   "iat" => 1574249015,
                                   "exp" => 1574335415,
                                   "idp.globalid.net/claims/dd24263d-079b-4779-9776-167fe6e03ab8" => { "bf4cd542-216f-4377-bc46-7601eca09048" => ["WQexnTFKt1EFbqTi60fjGTCV67lCZMxpjuw6Euv9VvIxAksVWOG+rcXddAhg9RyqnD5663wPaCjvQxZPGKjisz3Xcrll8BTzeSfEGY9GMM2pcXutmSZKDFuLgUXzDJqD9sl0ekWdVTb9SdnAVeAYkztmAYpf7E9KJTta5HyXEwXPKsI/L17MF5vuFGxfYL84P1tbCeB67pYtl4Cp1vVpg53oVu/wvWKWVOLgwDnRgkOa5gvTsROoxRqOhMoWaMLsTYREOUwfs1rv1mVKOtXXq9IkK6kZ6DfC5PgYKOCI3OLaOvNcWy8qd+zdGZBRXeyHDIFrotY1omAMTTBHmFNMwOQddTIWNVgKaPc4xV5q2NfCA6qdEREiSIysTPeWVgd134UvVNjCVTeTIb365hgB0Mj/tlMww8B1BqWPFmxYzFkyQkcUvNdJGqcwUpjjpQI/OxzzunhMLNZoxK1/PeSPRxDbo9Ii8QeJy2suQNqdSsCEqvKYHMN7WoLeyQaTs6GodIbL9KiIbsJ+LEAOvZwk7Z9h/eLFsGVzVv/ubRblWSpUQlJ+F/uU+FuFULJXwQJ3vAhwppxFzcElncrI5PeUqqXUVdC6w3A5b8qzVEmT172xNEOEjnsWZqls4uAJz7qIu/7xBRSPlX+fTD1GZaHhvTVfPESMeFvZYfTk1V10PJc="] },
                                   "idp.globalid.net/claims/null" => {} },
                   "decrypted_pii" => [{ "attestation_request_uuid" => "f0e18adc-fc68-414d-82f5-66a0407db8a4",
                                         "attestation_uuid" => "0337f200-74b5-4836-9a37-1f7e130fd842",
                                         "gid_uuid" => "ef141f5d-2a9f-429d-999f-8bbec78a733a",
                                         "has_attachment" => false,
                                         "timestamp" => "2019-10-07T23:23:41.759Z",
                                         "type" => "email",
                                         "value" => "seth@example.org",
                                         "value_type" => "PII" }] },
        "credentials" => { "token" => "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJjbGllbnRfaWQiOiI3MDEwMDNjNi0xZGNiLTQzZjctYTgwNS05ZjgwODM0MDk4YzUiLCJzY29wZSI6Im9wZW5pZCIsInV1aWQiOiJlZjE0MWY1ZC0yYTlmLTQyOWQtOTk5Zi04YmJlYzc4YTczM2EiLCJnbG9iYWxpZCI6InNldGhoZXJyIiwidmFsaWRfdG8iOiJXZWQsIDIwIE5vdiAyMDE5IDEzOjIzOjM0IEdNVCIsImNsaWVudF9uYW1lIjoiUmFpbHMgRGVtbyBhcHAiLCJleHAiOjE1NzQyNTYyMTQsInZhbGlkX3RvX3V0YyI6IjIwMTktMTEtMjBUMTM6MjM6MzQuOTQwWiIsImdyYW50X3R5cGUiOiJhdXRob3JpemF0aW9uX2NvZGUiLCJybmQiOiJieHpCWmdvbSIsImlhdCI6MTU3NDI0OTAxNX0.rCywzG2qegWhzG2uIGSX5JpGdlt3WZ6cSQ8_0afLVsG71H06QSk2XykZyG8MVzON-js83tO-urof_93O5s7FvVrvx0ViiizAoxUeuTRt6RCnWXyXUf7dun04Cmv2yCn1_UBh-qQBHAZLXHbtpOjiO1DgXkUe14pSiW83eTTH9pxncXx6Xn2DBBneA5WWCvAKY8GBdkRYPNp3vJazevGiCcaFYAO1IbEX4X_WEqmqW9nElh9yj2okjukz1oVMcJtxq7c6U5-zQits7K8z1gwtAe427YsGvIm4qV_mW-4XOw_X27ko8n2Rgj612LSJZeODUrVXwaSzpXruskqRRRD2hA",
                           "refresh_token" => "528f05c71612a9a42e5ab08c17a7e21e",
                           "expires_at" => 1574256212,
                           "expires" => true },
        "extra" => {},
      )
    end
    describe "create" do
      before { request.env["omniauth.auth"] = OmniAuth.config.mock_auth[:globalid] }
      context "when there is no user" do
        it "creates an integration" do
          expect do
            post :create
          end.to change(Integration, :count).by(1)
          expect(response.code).to eq("302")
          user = User.last
          expect(User.from_auth(cookies.signed[:auth])).to eq(user)
          expect(user.integrations.count).to eq 1
          expect(user.integrations.first.provider_name).to eq "globalid"
        end
      end

      describe "when there is a user" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: "seth@example.org") }

        it "creates a new integration given a refresh token and access token" do
          expect do
            get :create, params: { access_token: "123456", expires_in: "3920", token_type: "Bearer", refresh_token: "1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI" }
            expect(flash[:success]).to be_present
            expect(response).to redirect_to(my_account_url)
          end.to change(Integration, :count).by 1
        end

        context "user is already signed in" do
          before { set_current_user(user) }
          it "skips" do
            expect do
              get :create, params: { access_token: "123456", expires_in: "3920", token_type: "Bearer", refresh_token: "1/xEoDL4iW3cxlI7yDbSRFYNG01kVKM2C-259HOF2aQbI" }
            end.to change(Integration, :count).by 0
            expect(response).to redirect_to(my_account_url)
          end
        end
      end
    end
  end

  describe "failure" do
    it "renders sessions new with a flash" do
      get :integrations_controller_creation_error, params: { message: "csrf_detected", strategy: "facebook" }
      expect(flash[:error]).to match("email us at contact@bikeindex.org")
      expect(response).to redirect_to new_session_path
    end
  end
end
