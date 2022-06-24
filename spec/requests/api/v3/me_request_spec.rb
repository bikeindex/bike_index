require "rails_helper"

RSpec.describe "Me API V3", type: :request do
  include_context :existing_doorkeeper_app
  describe "token positioning" do
    before { expect(doorkeeper_app).to be_present }
    context "token in params" do
      it "responds" do
        expect(token.reload.acceptable?(nil)).to be_truthy
        expect(user.confirmed?).to be_truthy
        get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        pp response.body
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
          pp json_result
          expect(json_result["error"]).to match(/confirmed/i)
          expect(response.response_code).to eq(403)
        end
      end
    end
    context "token in header" do
      xit "responds" do
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
  # describe "unauthorized current" do
  #   it "Sends correct error code when no user present" do
  #     get "/api/v3/me"
  #     expect(response.response_code).to eq(401)
  #     expect(response.body.match("OAuth")).to be_present
  #     expect(response.headers["Content-Type"].match("json")).to be_present
  #     expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  #     expect(response.headers["Access-Control-Request-Method"]).to eq("*")
  #   end
  # end

  # describe "authorized current" do
  #   let!(:token) { create_doorkeeper_token(scopes: scopes) }
  #   let(:scopes) { "public read_user read_bikes" }

  #   context "fully scoped token" do
  #     let(:scopes) { all_scopes }
  #     let!(:secondary_email) { FactoryBot.create(:user_email, user: user, email: "d@f.co") }
  #     let!(:membership) { FactoryBot.create(:membership_claimed, user: user) }
  #     let(:target_membership) do
  #       {
  #         organization_name: membership.organization.name,
  #         organization_slug: membership.organization.slug,
  #         organization_id: membership.organization_id,
  #         organization_access_token: membership.organization.access_token,
  #         user_is_organization_admin: false
  #       }
  #     end
  #     it "responds with all available attributes with full scoped token" do
  #       user.reload
  #       expect(user.secondary_emails).to eq(["d@f.co"])
  #       get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
  #       expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  #       expect(json_result["user"]["name"]).to eq(user.name)
  #       expect(json_result["user"]["secondary_emails"]).to eq(["d@f.co"])
  #       expect(json_result["id"]).to eq(user.id.to_s)
  #       expect(json_result["user"].is_a?(Hash)).to be_truthy
  #       expect(json_result["bike_ids"].is_a?(Array)).to be_truthy
  #       expect(json_result["memberships"].is_a?(Array)).to be_truthy
  #       expect(json_result["memberships"]).to eq([target_membership.as_json])
  #       expect(response.response_code).to eq(200)
  #     end
  #   end

  #   context "unconfirmed user" do
  #     let(:time) { Time.current - 1.month }
  #     let(:user) { FactoryBot.create(:user, created_at: time) }
  #     it "responds with unauthorized" do
  #       user.reload
  #       expect(user.confirmed?).to be_falsey
  #       get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
  #       expect(response.response_code).to eq(403)
  #       expect(json_result[:error]).to be_present
  #     end

  #     context "app with unconfirmed scope" do
  #       let(:scopes) { "public read_user unconfirmed" }
  #       it "responds with all available attributes" do
  #         get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
  #         expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
  #         expect(json_result[:user][:name]).to eq(user.name)
  #         expect(json_result[:user][:secondary_emails]).to eq([])
  #         expect(json_result[:user][:confirmed]).to be_falsey
  #         expect(json_result[:id]).to eq(user.id.to_s)
  #         expect(Time.at(json_result[:user][:created_at])).to be_within(1.second).of time
  #         expect(json_result[:user].is_a?(Hash)).to be_truthy
  #         expect(json_result.key?("bike_ids")).to be_falsey
  #         expect(json_result.key?("memberships")).to be_falsey
  #         expect(response.response_code).to eq(200)
  #       end
  #       context "user not present" do
  #         it "responds with 401" do
  #           get "/api/v3/me", params: {access_token: "FAKETOKEN"}, headers: {format: :json}
  #           expect(response.response_code).to eq(401)
  #           expect(response.body.match("OAuth")).to be_present
  #         end
  #       end
  #     end
  #   end

  #   context "no bikes scoped" do
  #     let(:scopes) { "public" }
  #     it "doesn't include bikes" do
  #       expect(token.scopes.to_s.match("read_bikes").present?).to be_falsey
  #       get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
  #       expect(response.response_code).to eq(200)
  #       expect(json_result["id"]).to eq(user.id.to_s)
  #       expect(json_result["bike_ids"].present?).to be_falsey
  #       expect(json_result["user"]).to be_nil
  #     end
  #   end

  #   context "no membership scoped" do
  #     it "doesn't include memberships if no memberships scoped" do
  #       expect(token.scopes.to_s.match("read_organization_membership").present?).to be_falsey
  #       get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
  #       expect(response.response_code).to eq(200)
  #       result = JSON.parse(response.body)
  #       expect(result["id"]).to eq(user.id.to_s)
  #       expect(result["memberships"].present?).to be_falsey
  #     end
  #   end

  #   context "Default scope" do
  #     let(:scopes) { "" }
  #     it "doesn't include memberships" do
  #       get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
  #       expect(response.response_code).to eq(200)
  #       result = JSON.parse(response.body)
  #       expect(result["id"]).to eq(user.id.to_s)
  #       expect(result["user"].present?).to be_falsey
  #     end
  #   end
  # end

  # describe "current/bikes" do
  #   before { expect(doorkeeper_app).to be_present }

  #   it "works if it's authorized" do
  #     token.update_attribute :scopes, "read_bikes"
  #     get "/api/v3/me/bikes", headers: {
  #       "Authorization" => "Bearer #{token.token}",
  #       format: :json
  #     }
  #     expect(json_result["bikes"].is_a?(Array)).to be_truthy
  #     expect(response.response_code).to eq(200)
  #   end
  #   it "403s if read_bikes_spec isn't in token" do
  #     get "/api/v3/me/bikes", params: {access_token: token.token}, headers: {format: :json}
  #     expect(response.response_code).to eq(403)
  #   end
  # end
end
