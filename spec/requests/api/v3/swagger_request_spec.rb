require "rails_helper"

RSpec.describe "Swagger API V3 docs", type: :request do
  describe "all the paths" do
    let(:target_apis) do
      [{path: "/organizations", description: "Operations about organizations"},
        {path: "/search", description: "Searching for bikes"},
        {path: "/bikes", description: "Operations about bikes"},
        {path: "/me", description: "Operations about the current user"},
        {path: "/manufacturers", description: "Accepted manufacturers"},
        {path: "/selections", description: "Selections (static options)"}]
    end
    it "responds with swagger for all the endpoints" do
      get "/api/v3/swagger_doc"
      result = json_result
      expect(result["error"]).to be_blank
      expect(response.code).to eq("200")

      expect(json_result["apis"].count).to eq target_apis.count
      expect(json_result["apis"].map { |i| i[:path] }.sort)
        .to eq target_apis.map { |i| i[:path] }.sort
      expect(json_result["apis"].map { |i| i[:description] }.sort)
        .to eq target_apis.map { |i| i[:description] }.sort

      json_result["apis"].each do |endpoint|
        path, _desc = endpoint["path"], endpoint["description"]

        get "/api/v3/swagger_doc#{path}"

        expect(response.status).to eq(200)
        endpoint_response = JSON.parse(response.body)

        expect(endpoint_response["resourcePath"]).to eq path
        expect(endpoint_response["apis"].first["path"]).to match("/v3#{path}")
      end
    end
  end
end
