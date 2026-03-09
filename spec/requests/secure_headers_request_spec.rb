require "rails_helper"

RSpec.describe "SecureHeaders", type: :request do
  describe "cookie opt out" do
    it "does not join Set-Cookie headers with newlines" do
      # SecureHeaders::Middleware#flag_cookies! joins cookies with "\n"
      # which Puma 7 rejects as illegal header values.
      # config.cookies = SecureHeaders::OPT_OUT prevents this.
      user = FactoryBot.create(:user_confirmed)
      post "/session", params: {session: {email: user.email, password: "testthisthing7$"}}
      set_cookie = response.headers["Set-Cookie"]
      expect(set_cookie).to be_present
      expect(set_cookie).not_to include("\n")
    end
  end

  describe "security headers" do
    it "includes expected headers" do
      user = FactoryBot.create(:user_confirmed)
      post "/session", params: {session: {email: user.email, password: "testthisthing7$"}}
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
      expect(response.headers["X-Content-Type-Options"]).to eq("nosniff")
      # HSTS not present in test env, but present in production via SecureHeaders config
    end
  end
end
