# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Bikebook::ModelSearch do
  describe "matching" do
    before { sync_bikebook_models }

    def catalog_id(name, year, market = "US", manufacturer: "Specialized")
      described_class.matching(manufacturer_id: Manufacturer.friendly_find(manufacturer).id, name:, year:, market:)&.catalog_id
    end

    it "is the model sold that year, the one sold in its market of several" do
      kh24 = BikebookModel.find_by!(catalog_id: "m/kris-holm/2023/kh24")
      kh24.dup.update!(catalog_id: "m/kris-holm/2023/kh24-us")
      kh24.update!(markets: ["CA"])

      expect(catalog_id("Haul ST", 2026)).to eq "m/specialized/2025/haul-st"
      expect(catalog_id("haul-st", 2025, "US")).to eq "m/specialized/2025/haul-st"
      expect(catalog_id("Haul ST", 2025, "CA")).to eq "m/specialized/2025/haul-st"
      # sold in Canada as a variant, it's preferred there over one listed first
      BikebookModel.find_by!(catalog_id: "m/specialized/2025/haul-st").dup.update!(catalog_id: "m/specialized/2025/haul-sa", markets: ["US"])
      expect(catalog_id("Haul ST", 2025, "US")).to eq "m/specialized/2025/haul-sa"
      expect(catalog_id("Haul ST", 2025, "CA")).to eq "m/specialized/2025/haul-st"
      expect(catalog_id("Haul ST", 2024)).to be_nil
      expect(catalog_id("KH24", 2023, manufacturer: "Kris Holm")).to eq "m/kris-holm/2023/kh24-us"
      expect(catalog_id("KH24", 2023, "CA", manufacturer: "Kris Holm")).to eq "m/kris-holm/2023/kh24"
      expect(catalog_id("Nuke", 2024, manufacturer: "Reactive Adaptations")).to eq "m/reactive-adaptations/2013/nuke"
      expect(catalog_id("Nuke", 2025, manufacturer: "Reactive Adaptations")).to be_nil
    end
  end

  describe "slug" do
    it "slugifies, without cycle words" do
      expect(described_class.slug("Cross-check Singlespeed BicyclE")).to eq "cross-check-singlespeed"
      expect(described_class.slug("Turbo Vado E-Bike")).to eq "turbo-vado"
    end

    it "keeps parenthesized text" do
      expect(described_class.slug("Sprint Ultegra 11sp (SPECIFIC FOR ASIA)")).to eq "sprint-ultegra-11sp-specific-for-asia"
    end
  end
end
