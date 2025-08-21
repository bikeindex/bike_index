require "rails_helper"

RSpec.describe Country, type: :model do
  describe "factory" do
    let(:country) { FactoryBot.create(:country_australia) }
    it "is valid and only creates once" do
      expect(country).to be_valid
      expect(FactoryBot.create(:country_australia).id).to eq country.id
    end

    context "united_states" do
      let(:country) { Country.united_states }

      it "matches class methods" do
        expect(country.id).to eq Country.united_states_id
      end
    end
  end

  describe "friendly_find" do
    it "finds the country by name or iso" do
      country = Country.create(name: "Svenborgia", iso: "SVE")
      expect(Country.friendly_find(" SVENBORGia")).to eq(country)
      expect(Country.friendly_find(" sve ")).to eq(country)
    end

    it "finds the country by ISO address when the case doesn't match" do
      country = Country.create(name: "EEEEEEEh", iso: "LULZ")
      expect(Country.friendly_find("lulz ")).to eq(country)
    end

    it "finds the United States by its proper ISO or 'USA'" do
      country = Country.create(name: "United States", iso: "US")
      expect(Country.friendly_find("USA")).to eq(country)
      expect(Country.friendly_find("us")).to eq(country)
    end
  end
end
