require "spec_helper"

describe "Me API V3" do
  include_context :existing_doorkeeper_app
  describe "unauthorized current" do
    it "Sends correct error code when no user present" do
      get "/api/v3/me"
      expect(response.response_code).to eq(401)
      expect(response.body.match("OAuth")).to be_present
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Request-Method"]).to eq("*")
    end
  end

  describe "authorized current" do
    let!(:token) { create_doorkeeper_token(scopes: scopes) }
    let(:scopes) { "public read_user read_bikes" }

    context "fully scoped token" do
      let(:scopes) { all_scopes }
      let!(:secondary_email) { FactoryGirl.create(:user_email, user: user, email: "d@f.co") }
      it "responds with all available attributes with full scoped token" do
        user.reload
        expect(user.secondary_emails).to eq(["d@f.co"])
        get "/api/v3/me", format: :json, access_token: token.token
        result = JSON.parse(response.body)
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(result["user"]["name"]).to eq(user.name)
        expect(result["user"]["secondary_emails"]).to eq(["d@f.co"])
        expect(result["id"]).to eq(user.id.to_s)
        expect(result["user"].is_a?(Hash)).to be_truthy
        expect(result["bike_ids"].is_a?(Array)).to be_truthy
        expect(result["memberships"].is_a?(Array)).to be_truthy
        expect(response.response_code).to eq(200)
      end
    end

    context "unconfirmed user" do
      let(:user) { FactoryGirl.create(:user) }
      it "responds with unauthorized" do
        user.reload
        expect(user.confirmed?).to be_falsey
        get "/api/v3/me", format: :json, access_token: token.token
        result = JSON.parse(response.body)
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(result["user"]["name"]).to eq(user.name)
        expect(result["user"]["secondary_emails"]).to eq([])
        expect(result["user"]["confirmed"]).to be_falsey
        expect(result["id"]).to eq(user.id.to_s)
        expect(result["user"].is_a?(Hash)).to be_truthy
        expect(result.keys.include?("bike_ids")).to be_falsey
        expect(result.keys.include?("memberships")).to be_falsey
        expect(response.response_code).to eq(200)
      end

      context "app with unconfirmed scope" do
        let(:scopes) { "public read_user unconfirmed" }
        it "responds with all available attributes" do
          user.reload
          expect(user.confirmed?).to be_falsey
          get "/api/v3/me", format: :json, access_token: token.token
          result = JSON.parse(response.body)
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(result["user"]["name"]).to eq(user.name)
          expect(result["user"]["secondary_emails"]).to eq([])
          expect(result["user"]["confirmed"]).to be_falsey
          expect(result["id"]).to eq(user.id.to_s)
          expect(result["user"].is_a?(Hash)).to be_truthy
          expect(result.keys.include?("bike_ids")).to be_falsey
          expect(result.keys.include?("memberships")).to be_falsey
          expect(response.response_code).to eq(200)
        end
      end
    end

    context "no bikes scoped" do
      let(:scopes) { "public" }
      it "doesn't include bikes" do
        expect(token.scopes.to_s.match("read_bikes").present?).to be_falsey
        get "/api/v3/me", format: :json, access_token: token.token
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result["id"]).to eq(user.id.to_s)
        expect(result["bike_ids"].present?).to be_falsey
        expect(result["user"]).to be_nil
      end
    end

    context "no membership scoped" do
      it "doesn't include memberships if no memberships scoped" do
        expect(token.scopes.to_s.match("read_organization_membership").present?).to be_falsey
        get "/api/v3/me", format: :json, access_token: token.token
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result["id"]).to eq(user.id.to_s)
        expect(result["memberships"].present?).to be_falsey
      end
    end

    context "Default scope" do
      let(:scopes) { "" }
      it "doesn't include memberships" do
        get "/api/v3/me", format: :json, access_token: token.token
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result["id"]).to eq(user.id.to_s)
        expect(result["user"].present?).to be_falsey
      end
    end
  end

  describe "current/bikes" do
    before { expect(doorkeeper_app).to be_present }

    it "works if it's authorized" do
      token.update_attribute :scopes, "read_bikes"
      get "/api/v3/me/bikes", format: :json, access_token: token.token
      # get "/api/v3/me/bikes", {}, "Authorization" => "Basic #{Base64.encode64("#{token.token}:X")}"
      result = JSON.parse(response.body)
      expect(result["bikes"].is_a?(Array)).to be_truthy
      expect(response.response_code).to eq(200)
    end
    it "403s if read_bikes_spec isn't in token" do
      get "/api/v3/me/bikes", format: :json, access_token: token.token
      expect(response.response_code).to eq(403)
    end
  end
end
