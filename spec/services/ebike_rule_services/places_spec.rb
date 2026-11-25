# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRuleServices::Places do
  before { stub_bikebook_catalog }

  describe "all" do
    it "lists the states by their US- code, then the places outside the US by name" do
      places = described_class.all
      expect(places.first).to eq(code: "US-AL", name: "Alabama", abbr: "AL")
      expect(places.count { described_class.us?(it) }).to eq 51
      expect(places.reject { described_class.us?(it) }).to eq [{code: "CA", name: "Canada"}, {code: "EU", name: "European Union"},
        {code: "CA-NB", name: "New Brunswick"}, {code: "CA-ON", name: "Ontario"}]
    end
  end

  describe "find" do
    it "finds a place by its exact code" do
      expect(described_class.find("US-CO")).to eq(code: "US-CO", name: "Colorado", abbr: "CO")
      expect(described_class.find("CA")).to eq(code: "CA", name: "Canada")
      expect(described_class.find("ca")).to be_nil
      expect(described_class.find("CO")).to be_nil
      expect(described_class.find(["CA"])).to be_nil
    end
  end

  describe "checked_country" do
    it "is a checked country's, for the place or its regions, else the US's" do
      expect(described_class.checked_country(described_class.find("CA-ON"))).to eq "CA"
      expect(described_class.checked_country(described_class.find("CA"))).to eq "CA"
      expect(described_class.checked_country(described_class.find("US-CO"))).to eq "US"
      expect(described_class.checked_country(described_class.find("EU"))).to eq "US"
      expect(described_class.checked_country(nil)).to eq "US"
    end
  end

  describe "checks?" do
    it "is a checked country's region, not the country" do
      expect(%w[US-CO CA-ON CA EU].map { described_class.checks?(described_class.find(it)) }).to eq [true, true, false, false]
    end
  end

  describe "regions" do
    it "is the US's states, or the country's regions the catalog has" do
      expect(described_class.regions("US").count).to eq 51
      expect(described_class.regions("CA").pluck(:code)).to eq %w[CA-NB CA-ON]
    end
  end

  describe "from_location" do
    let(:location) { ->(iso, region = nil) { {country_id: Country.friendly_find_id(iso), region_string: region} } }

    it "is a US state, a region the catalog has, else its country, or for an EU member, the EU" do
      FactoryBot.create(:country, iso: "DE", name: "Germany")
      FactoryBot.create(:country, iso: "JP", name: "Japan")
      expect(described_class.from_location(location.call("US", "Colorado"))).to include(code: "US-CO")
      expect(described_class.from_location(location.call("CA", "New Brunswick"))).to include(code: "CA-NB")
      expect(described_class.from_location(location.call("CA", "NB"))).to include(code: "CA-NB")
      expect(described_class.from_location(location.call("CA", "Ontario"))).to include(code: "CA-ON")
      expect(described_class.from_location(location.call("CA", "Quebec"))).to include(code: "CA")
      expect(described_class.from_location(location.call("DE"))).to include(code: "EU")
      expect(described_class.from_location(location.call("JP"))).to be_nil
      expect(described_class.from_location({})).to be_nil
    end
  end
end
