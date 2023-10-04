require "rails_helper"

base_url = "/api/autocomplete"
RSpec.describe "API::Autocomplete", type: :request do
  describe "index" do
    let!(:color) { FactoryBot.create(:color, name: "Silver, gray or bare metal") }
    before do
      Autocomplete::Loader.clear_redis
      Autocomplete::Loader.load_all(["Color"])
    end
    let(:target) { color.autocomplete_hash.except(:data).merge(color.autocomplete_hash[:data]) }
    it "responds" do
      get base_url, params: {format: :json}
      expect(response.code).to eq("200")
      expect(json_result.keys).to eq(["matches"])
      expect(json_result["matches"].count).to eq 1
      expect_hashes_to_match(json_result["matches"].first, target)
    end
  end
end
