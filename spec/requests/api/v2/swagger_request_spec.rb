require "rails_helper"

RSpec.describe "Swagger API V2 docs", type: :request do
  describe "all the paths" do
    let(:target_apis) do
      [
        {path: "/bikes_search", description: "Searching for bikes"},
        {path: "/bikes", description: "Operations about bikes"},
        {path: "/me", description: "Operations about the current user"},
        {path: "/users", description: "Deprecated"},
        {path: "/manufacturers", description: "Accepted manufacturers"},
        {path: "/selections", description: "Selections (static options)"}
      ]
    end
    it "responds with swagger for all the apis" do
      get "/api/v2/swagger_doc"

      expect(response.code).to eq("200")

      expect(json_result["apis"].count).to eq target_apis.count
      expect(json_result["apis"].map { |i| i[:path] }.sort)
        .to eq target_apis.map { |i| i[:path] }.sort
      expect(json_result["apis"].map { |i| i[:description] }.sort)
        .to eq target_apis.map { |i| i[:description] }.sort

      json_result["apis"].each do |endpoint|
        path, desc = endpoint["path"], endpoint["description"]

        get "/api/v2/swagger_doc#{path}"

        code = /deprecated/i.match?(desc) ? 404 : 200
        expect(response.status).to eq(code)
        next if code == 404
        endpoint_response = JSON.parse(response.body)

        expect(endpoint_response["resourcePath"]).to eq path
        expect(endpoint_response["apis"].first["path"]).to match("/v2#{path}")
      end
    end
  end
end
