require "rails_helper"

RSpec.describe Manufacturer, type: :model do
  it_behaves_like "autocomplete_hashable"

  describe "ensure_non_blocking_name" do
    before { FactoryBot.create(:color, name: "Purple") }
    context "name same as a color" do
      it "adds an error" do
        manufacturer = FactoryBot.build(:manufacturer, name: " pURple ")
        manufacturer.valid?
        expect(manufacturer.errors.full_messages.to_s).to match "same as a color"
      end
    end
    context "name includes a color" do
      it "adds no error" do
        manufacturer = FactoryBot.build(:manufacturer, name: "Purple bikes")
        manufacturer.valid?
        expect(manufacturer.errors.count).to eq 0
      end
    end
    context "name with single quote" do
      let(:manufacturer) { FactoryBot.build(:manufacturer, name: "stuff'") }
      it "is valid" do
        expect(manufacturer.valid?).to be_truthy
      end
    end
    context "name with double quote" do
      let(:manufacturer) { FactoryBot.build(:manufacturer, name: 'stuff"') }
      it "adds an error" do
        expect(manufacturer.valid?).to be_falsey
        expect(manufacturer.errors.full_messages.to_s).to match "quote"
      end
    end
  end

  describe "friendly_find" do
    it "finds manufacturers by their slug" do
      mnfg = FactoryBot.create(:manufacturer, name: "Poopy PANTERS")
      expect(Manufacturer.friendly_find("poopy panters")).to eq(mnfg)
    end
    it "removes Accell (because it's widespread mnfg)" do
      mnfg = FactoryBot.create(:manufacturer, name: "Poopy PANTERS")
      expect(Manufacturer.friendly_find("poopy panters Accell")).to eq(mnfg)
    end
    it "finds with dashes" do
      mnfg = FactoryBot.create(:manufacturer, name: "All City")
      expect(mnfg.secondary_name).to be_nil
      expect(mnfg.secondary_slug).to be_nil
      expect(Manufacturer.friendly_find("All-city ")&.id).to eq(mnfg.id)
      expect(Manufacturer.find_by_secondary_slug("All-city ")&.id).to be_nil
    end
    it "finds in the secondary_slug" do
      mnfg = FactoryBot.create(:manufacturer, name: "S & M (S and M Bikes) ")
      expect(mnfg.secondary_name).to eq "S and M Bikes"
      expect(mnfg.secondary_slug).to eq "s_and_m"
      expect(Manufacturer.friendly_find("s & m")&.id).to eq mnfg.id
      expect(Manufacturer.find_by_secondary_slug("s_and_m")&.id).to eq mnfg.id
      expect(Manufacturer.friendly_find("s and m bikes")&.id).to eq mnfg.id
      expect(Manufacturer.friendly_find("s and m")&.id).to eq mnfg.id
    end
  end

  describe "autocomplete_hash" do
    it "returns what we expect" do
      manufacturer = FactoryBot.create(:manufacturer)
      result = manufacturer.autocomplete_hash
      expect(result.keys).to eq(%i[id text category priority data])
      expect(result[:data][:slug]).to eq manufacturer.slug
      expect(result[:data][:search_id]).to eq("m_#{manufacturer.id}")
    end
  end

  describe "autocomplete_hash_category" do
    context "0 bikes or components" do
      it "returns 0" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 0 }
        allow(manufacturer).to receive(:c_count) { 0 }
        expect(manufacturer.send(:calculated_priority)).to eq(0)
      end
    end
    context "1 component" do
      it "returns 10" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 0 }
        allow(manufacturer).to receive(:c_count) { 2 }
        expect(manufacturer.send(:calculated_priority)).to eq(10)
      end
    end
    context "25 bikes and 50 components" do
      it "returns 15" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 24 }
        allow(manufacturer).to receive(:c_count) { 50 }
        expect(manufacturer.send(:calculated_priority)).to eq(14)
      end
    end
    context "1020 bikes" do
      it "returns 100" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:b_count) { 1020 }
        allow(manufacturer).to receive(:c_count) { 3 }
        expect(manufacturer.send(:calculated_priority)).to eq(100)
      end
    end
  end

  describe "friendly_find_id" do
    it "gets id from name" do
      manufacturer = FactoryBot.create(:manufacturer)
      result = Manufacturer.friendly_find_id(manufacturer.name)
      expect(result).to eq(manufacturer.id)
    end
    it "fails with nil" do
      result = Manufacturer.friendly_find_id("some stuff")
      expect(result).to be_nil
    end
  end

  describe "calculated_mnfg_name" do
    let(:manufacturer_other) { Manufacturer.other }
    let(:manufacturer) { Manufacturer.new(name: "Mnfg name") }
    it "returns the value of manufacturer_other if manufacturer is other" do
      expect(Manufacturer.calculated_mnfg_name(manufacturer, "Other manufacturer name")).to eq "Mnfg name"
      expect(Manufacturer.calculated_mnfg_name(manufacturer_other, "Other manufacturer name")).to eq("Other manufacturer name")
      expect(manufacturer.simple_name).to eq "Mnfg name"
      expect(manufacturer.secondary_name).to be_nil
    end

    it "returns the name of the manufacturer if it isn't other" do
      expect(Manufacturer.calculated_mnfg_name(manufacturer, nil)).to eq("Mnfg name")
    end

    context "malicious" do
      let(:malicious_str) { '<a href="bad_site.js">stuff</a>' }
      it "removes bad things" do
        expect(Manufacturer.calculated_mnfg_name(manufacturer_other, malicious_str)).to eq "stuff"
      end
    end

    context "weird stuff" do
      let(:malicious_str) { "Sweet manufacturer <><>><\\" }
      let(:target) { "Sweet manufacturer &lt;&gt;&lt;&gt;&gt;&lt;\\" }
      it "encodes" do
        expect(Manufacturer.calculated_mnfg_name(manufacturer_other, malicious_str)).to eq target
      end
    end

    context "manufacturer with parens" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "SE Racing (S E Bikes)") }
      it "returns Just SE Bikes (and does it on save)" do
        expect(Manufacturer.calculated_mnfg_name(manufacturer, nil)).to eq "SE Racing"
        expect(manufacturer.reload.name).to eq "SE Racing (S E Bikes)"
        expect(manufacturer.simple_name).to eq "SE Racing"
        expect(manufacturer.secondary_name).to eq "S E Bikes"
      end
    end
  end

  describe "set_calculated_attributes" do
    it "sets twitter_name" do
      manufacturer = Manufacturer.new(twitter_name: "@cool-thing")
      manufacturer.set_calculated_attributes
      expect(manufacturer.twitter_name).to eq "cool-thing"
    end
    it "sets logo source" do
      manufacturer = Manufacturer.new
      allow(manufacturer).to receive(:logo).and_return("http://example.com/logo.png")
      manufacturer.set_calculated_attributes
      expect(manufacturer.logo_source).to eq("manual")
    end

    it "doesn't overwrite logo source" do
      manufacturer = Manufacturer.new(logo_source: "something cool")
      allow(manufacturer).to receive(:logo).and_return("http://example.com/logo.png")
      manufacturer.set_calculated_attributes
      expect(manufacturer.logo_source).to eq("something cool")
    end

    it "empties" do
      manufacturer = Manufacturer.new(logo_source: "something cool", description: " ")
      manufacturer.set_calculated_attributes
      expect(manufacturer.logo_source).to be_nil
      expect(manufacturer.description).to be_nil
    end
  end
end
