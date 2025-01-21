require "rails_helper"

base_url = "/api/v1/component_types"
RSpec.describe API::V1::ComponentTypesController, type: :request do
  describe "index" do
    it "loads the request" do
      FactoryBot.create(:ctype)
      get base_url, headers: {format: :json}
      expect(response.code).to eq("200")
    end
  end
end
