require "rails_helper"

base_url = "/api/v2"
RSpec.describe "Me API V2", type: :request do
  include_context :existing_doorkeeper_app
  describe "unauthorized current" do
    it "Sends correct error code when no user present" do
      get "#{base_url}/me"
      expect(response.response_code).to eq(401)
      expect(response.body.match("OAuth")).to be_present
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Request-Method"]).to eq("*")
    end
  end

  describe "authorized current" do
    before { expect(doorkeeper_app).to be_present }

    it "responds with all available attributes with full scoped token" do
      token.update_attribute :scopes, all_scopes
      get "#{base_url}/me", params: {access_token: token.token, format: :json}
      result = JSON.parse(response.body)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(result["user"]["name"]).to eq(user.name)
      expect(result["user"]["secondary_emails"]).to eq([])
      expect(result["id"]).to eq(user.id.to_s)
      expect(result["user"].is_a?(Hash)).to be_truthy
      expect(result["bike_ids"].is_a?(Array)).to be_truthy
      expect(result["organization_roles"].is_a?(Array)).to be_truthy
      expect(response.response_code).to eq(200)
    end

    it "responds with all available attributes with full scoped token" do
      token.update_attribute :scopes, all_scopes
      get "#{base_url}/me", params: {access_token: token.token, format: :json}
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(result["id"]).to eq(user.id.to_s)
      expect(result["user"].is_a?(Hash)).to be_truthy
      expect(result["bike_ids"].is_a?(Array)).to be_truthy
      expect(result["organization_roles"].is_a?(Array)).to be_truthy
    end

    it "doesn't include bikes if no bikes scoped" do
      expect(token.scopes.to_s.match("read_bikes").present?).to be_falsey
      get "#{base_url}/me", params: {access_token: token.token, format: :json}
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(result["id"]).to eq(user.id.to_s)
      expect(result["bike_ids"].present?).to be_falsey
    end

    it "doesn't include organization_roles if no organization_roles scoped" do
      expect(token.scopes.to_s.match("read_organization_membership").present?).to be_falsey
      get "#{base_url}/me", params: {access_token: token.token, format: :json}
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(result["id"]).to eq(user.id.to_s)
      expect(result["organization_roles"].present?).to be_falsey
    end

    it "doesn't include organization_roles if no organization_roles scoped" do
      get "#{base_url}/me", params: {access_token: token.token, format: :json}
      expect(response.response_code).to eq(200)
      result = JSON.parse(response.body)
      expect(result["id"]).to eq(user.id.to_s)
      expect(result["user"].present?).to be_falsey
    end

    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      it "responds with 403" do
        expect(user.reload.confirmed?).to be_falsey
        expect(token.reload.acceptable?([])).to be_truthy
        get "#{base_url}/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(json_result["error"]).to match(/confirmed/i)
        expect(response.response_code).to eq(403)
      end
      context "with unconfirmed scope" do
        it "responds" do
          token.update(scopes: "unconfirmed")
          expect(user.reload.confirmed?).to be_falsey
          expect(token.reload.acceptable?([])).to be_truthy
          get "#{base_url}/me", params: {access_token: token.token}, headers: {format: :json}
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(json_result["error"]).to match(/confirmed/i)
          expect(response.response_code).to eq(403)
        end
      end
    end
  end

  describe "current/bikes" do
    before { expect(doorkeeper_app).to be_present }

    it "works if it's authorized" do
      token.update_attribute :scopes, "read_bikes"
      get "#{base_url}/me/bikes", params: {access_token: token.token, format: :json}
      # get '#{base_url}/me/bikes', {}, 'Authorization' => "Basic #{Base64.encode64("#{token.token}:X")}"
      result = JSON.parse(response.body)
      expect(result["bikes"].is_a?(Array)).to be_truthy
      expect(response.response_code).to eq(200)
    end
    it "403s if read_bikes_spec isn't in token" do
      get "#{base_url}/me/bikes", params: {access_token: token.token, format: :json}
      expect(response.response_code).to eq(403)
    end
  end
end
