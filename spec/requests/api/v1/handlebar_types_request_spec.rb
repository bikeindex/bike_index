require "rails_helper"

base_url = "/api/v1/handlebar_types"
RSpec.describe API::V1::HandlebarTypesController, type: :request do
  describe "index" do
    it "loads the page" do
      get base_url, headers: {format: :json}
      expect(response.code).to eq("200")
    end
  end
end
