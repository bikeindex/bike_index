require "rails_helper"

RSpec.describe "Swagger API V3 docs", type: :request do
  describe "all the paths" do
    it "responds with swagger for all the endpoints" do
      get "/api/v3/swagger_doc"
      result = json_result
      expect(result["error"]).to be_blank
      expect(response.code).to eq("200")
      result["apis"].each do |api|
        get "/api/v3/swagger_doc#{api["path"]}"
        expect(response.code).to eq("200")
      end
    end
  end
end
