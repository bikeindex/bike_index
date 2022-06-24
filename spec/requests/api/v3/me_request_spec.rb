require "rails_helper"

RSpec.describe "Me API V3", type: :request do
  include_context :existing_doorkeeper_app
  describe "token positioning" do
    before { expect(doorkeeper_app).to be_present }
    let(:user) { FactoryBot.create(:user_confirmed) }
    context "token in params" do
      it "responds" do
        expect(token.reload.acceptable?(nil)).to be_truthy
        expect(User.find(token.resource_owner_id).confirmed?).to be_truthy
        expect(user.confirmed?).to be_truthy
        get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(json_result).to eq({"id" => user.id.to_s})
        expect(response.response_code).to eq(200)
      end
      context "revoked_token" do
        it "responds with 403" do
          token.update(revoked_at: Time.current - 30.seconds)
          expect(token.reload.acceptable?([])).to be_falsey
          get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(json_result["error"]).to match(/revoked/i)
          expect(response.response_code).to eq(401)
        end
      end
      context "expired_token" do
        it "responds with 403" do
          token.update(created_at: Time.current - 2.days, expires_in: 3600)
          expect(token.reload.acceptable?([])).to be_falsey
          get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(json_result["error"]).to match(/expired/i)
          expect(response.response_code).to eq(401)
        end
      end
      context "unconfirmed user" do
        let(:user) { FactoryBot.create(:user) }
        it "responds with 403" do
          expect(user.reload.confirmed?).to be_falsey
          expect(token.reload.acceptable?([])).to be_truthy
          get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(json_result["error"]).to match(/confirmed/i)
          expect(response.response_code).to eq(403)
        end
      end
    end
    context "token in header" do
      it "responds" do
        get "/api/v3/me", headers: {
          "Authorization" => "Bearer #{token.token}",
          format: :json
        }
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(json_result).to eq({"id" => user.id.to_s})
        expect(response.response_code).to eq(200)
      end
      # it "responds when passed token in basic format" do
      #   get "/api/v3/me", headers: {
      #     "Authorization" => "Basic #{Base64.encode64("#{token.token}")}",
      #     format: :json
      #   }
      #   expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      #   expect(json_result).to eq({"id" => user.id.to_s})
      #   expect(response.response_code).to eq(200)
      # end
    end
  end
end
