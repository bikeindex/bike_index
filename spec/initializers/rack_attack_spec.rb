require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  include_context :rack_attack

  let(:password) { "example_password2" }
  let!(:user) { FactoryBot.create(:user_confirmed, password:, password_confirmation: password) }

  describe "sign_in/ip throttle (10/min)" do
    it "allows requests under the limit" do
      post "/session", params: {session: {email: user.email, password:}}
      expect(response.status).to_not eq 429
    end

    it "returns 429 after exceeding the limit" do
      10.times do
        post "/session", params: {session: {email: user.email, password:}}
      end
      post "/session", params: {session: {email: user.email, password:}}
      expect(response).to have_http_status(:too_many_requests)
      expect(response.headers["retry-after"]).to eq "60"
      expect(response.body).to eq "Too Many Requests"
    end
  end

  describe "sensitive_auth/ip throttle (5/min)" do
    %w[
      /session/create_magic_link
      /users/send_password_reset_email
    ].each do |path|
      context "POST #{path}" do
        it "returns 429 after exceeding the limit" do
          5.times { post path }
          post path
          expect(response).to have_http_status(:too_many_requests)
        end
      end
    end

    context "POST /user_emails/:id/resend_confirmation" do
      it "returns 429 after exceeding the limit" do
        5.times { post "/user_emails/123/resend_confirmation" }
        post "/user_emails/123/resend_confirmation"
        expect(response).to have_http_status(:too_many_requests)
      end
    end
  end
end
