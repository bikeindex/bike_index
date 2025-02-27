require "rails_helper"

base_url = "/api/v1/stolen_locking_response_suggestions"
RSpec.describe API::V1::StolenLockingResponseSuggestionsController, type: :request do
  describe "index" do
    it "loads the page" do
      get base_url, headers: {format: :json}
      expect(response.code).to eq("200")
      result = JSON.parse(response.body)
      expect(result["locking_defeat_descriptions"].count).to eq(6)
      expect(result["locking_descriptions"].count).to eq(8)
    end
  end
end
