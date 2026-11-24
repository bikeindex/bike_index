# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikebookModel, type: :model do
  before { sync_bikebook_models }

  describe "catalog_id_for" do
    def catalog_id(name, year, market = nil, manufacturer: "Specialized")
      described_class.catalog_id_for(manufacturer_id: Manufacturer.friendly_find(manufacturer).id, name:, year:, market:)
    end

    it "is the model sold that year, its market's variant or the model sold there" do
      kh24 = BikebookModel.find_by!(catalog_id: "m/kris-holm/2023/kh24")
      kh24.dup.update!(catalog_id: "m/kris-holm/2023/kh24-us")
      kh24.update!(markets: ["CA"])

      expect(catalog_id("Haul ST", 2026)).to eq "m/specialized/2025/haul-st"
      expect(catalog_id("haul-st", 2025, "US")).to eq "m/specialized/2025/haul-st"
      expect(catalog_id("Haul ST", 2025, "CA")).to eq "m/specialized/2025/haul-st@CA"
      expect(catalog_id("Haul ST", 2024)).to be_nil
      expect(catalog_id("KH24", 2023, manufacturer: "Kris Holm")).to eq "m/kris-holm/2023/kh24-us"
      expect(catalog_id("KH24", 2023, "CA", manufacturer: "Kris Holm")).to eq "m/kris-holm/2023/kh24"
      expect(catalog_id("Nuke", 2024, manufacturer: "Reactive Adaptations")).to eq "m/reactive-adaptations/2013/nuke"
      expect(catalog_id("Nuke", 2025, manufacturer: "Reactive Adaptations")).to be_nil
    end
  end
end
