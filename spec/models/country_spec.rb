require "rails_helper"

RSpec.describe Country, type: :model do
  describe "fuzzy_find" do
    it "finds the country by name or iso" do
      country = Country.create(name: "Svenborgia", iso: "SVE")
      expect(Country.fuzzy_find(" SVENBORGia")).to eq(country)
      expect(Country.fuzzy_find(" sve ")).to eq(country)
    end

    it "finds the country by ISO address when the case doesn't match" do
      country = Country.create(name: "EEEEEEEh", iso: "LULZ")
      expect(Country.fuzzy_find("lulz ")).to eq(country)
    end

    it "finds the United States by its proper ISO or 'USA'" do
      country = Country.create(name: "United States", iso: "US")
      expect(Country.fuzzy_find("USA")).to eq(country)
      expect(Country.fuzzy_find("us")).to eq(country)
    end
  end
end
