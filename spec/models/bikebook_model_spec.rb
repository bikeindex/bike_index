# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikebookModel, type: :model do
  before { sync_bikebook_models }

  describe "catalog_id_for" do
    def catalog_id(name, year, market = nil, manufacturer: "Specialized")
      described_class.catalog_id_for(manufacturer:, name:, year:, market:)
    end

    it "is the model sold that year, its market's variant or the model sold there" do
      expect(catalog_id("Haul ST", 2026)).to eq "m/specialized/2025/haul_st"
      expect(catalog_id("haul-st", 2025, "US")).to eq "m/specialized/2025/haul_st"
      expect(catalog_id("Haul ST", 2025, "CA")).to eq "m/specialized/2025/haul_st_ca"
      expect(catalog_id("Haul ST", 2024)).to be_nil
      expect(catalog_id("KH24", 2023, manufacturer: "Kris Holm")).to eq "m/kris_holm/2023/kh24"
      expect(catalog_id("KH24", 2023, "US", manufacturer: "Kris Holm")).to eq "m/kris_holm/2023/kh24_us"
      expect(catalog_id("Nuke", 2024, manufacturer: "Reactive Adaptations")).to eq "m/reactive_adaptations/2013/nuke"
      expect(catalog_id("Nuke", 2025, manufacturer: "Reactive Adaptations")).to be_nil
    end
  end

  describe "names_matching" do
    def names(query, page: 1, per_page: 15) = described_class.for_manufacturer("Specialized").names_matching(query, page:, per_page:)

    it "is the manufacturer's names with every word in them, a page at a time" do
      expect(names("ro")).to eq ["Roll 1", "Roll 2", "Roll 3", "Roll Trike"]
      expect(names("trike ROLL")).to eq ["Roll Trike"]
      expect(names("ro", page: 2, per_page: 3)).to eq ["Roll Trike"]
      expect(names("")).to include("Haul ST", "Crux 5 S-Level - SRAM RED XPLR")
      expect(names("%")).to eq []
    end
  end
end
