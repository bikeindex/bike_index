require "rails_helper"

RSpec.describe "Swagger API V2 docs", type: :request do
  describe "all the paths" do
    it "responds with swagger for all the apis" do
      get "/api/v2/swagger_doc"

      expect(response.code).to eq("200")

      json_result["apis"].each do |endpoint|
        path, desc = endpoint["path"], endpoint["description"]

        get "/api/v2/swagger_doc#{path}"

        code = (desc =~ /deprecated/i) ? 404 : 200
        expect(response.status).to eq(code)
      end
    end

    it "redirects to documentation on API call" do
      get "/api"
      expect(response).to redirect_to("/documentation")
    end
  end
end
