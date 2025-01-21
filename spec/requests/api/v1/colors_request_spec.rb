require "rails_helper"

base_url = "/api/v1/colors"
RSpec.describe API::V1::ColorsController, type: :request do
  describe "index" do
    it "loads the page" do
      FactoryBot.create(:color)
      get base_url, headers: {format: :json}
      expect(response.code).to eq("200")
    end
  end
end
