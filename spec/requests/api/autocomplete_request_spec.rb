require "rails_helper"

base_url = "/api/autocomplete"
RSpec.describe "API::Autocomplete", type: :request do
  describe "index" do
    let(:bike_hash) { CycleType.new(:bike).autocomplete_hash }
    before do
      Soulheart::Loader.new.clear(true)
      Soulheart::Loader.new.load([bike_hash])
    end
    it "responds" do
      get base_url, params: {format: :json}
      expect(response.code).to eq("200")
      expect(json_result).to eq({"matches" => []})
    end
  end
end
