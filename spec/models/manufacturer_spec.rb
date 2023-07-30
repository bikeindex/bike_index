require "rails_helper"

RSpec.describe Manufacturer, type: :model do
  it_behaves_like "autocomplete_hashable"

  describe "scopes" do
    it "default_scope is alphabetized" do
      expect(Manufacturer.all.to_sql).to eq(Manufacturer.unscoped.order(:name).to_sql)
    end
  end

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
  end

  describe "autocomplete_hash" do
    it "returns what we expect" do
      manufacturer = FactoryBot.create(:manufacturer)
      result = manufacturer.autocomplete_hash
      expect(result.keys).to eq(%w[id text category priority data])
      expect(result["data"]["slug"]).to eq manufacturer.slug
      expect(result["data"]["search_id"]).to eq("m_#{manufacturer.id}")
    end
  end

  describe "autocomplete_hash_category" do
    context "0 bikes or components" do
      it "returns 0" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { [] }
        allow(manufacturer).to receive(:components) { [] }
        expect(manufacturer.autocomplete_hash_priority).to eq(0)
      end
    end
    context "1 component" do
      it "returns 10" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { [] }
        allow(manufacturer).to receive(:components) { [2] }
        expect(manufacturer.autocomplete_hash_priority).to eq(10)
      end
    end
    context "25 bikes and 50 components" do
      it "returns 15" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { Array(0..24) }
        allow(manufacturer).to receive(:components) { Array(0..50) }
        expect(manufacturer.autocomplete_hash_priority).to eq(15)
      end
    end
    context "1020 bikes" do
      it "returns 100" do
        manufacturer = Manufacturer.new
        allow(manufacturer).to receive(:bikes) { Array(1..1020) }
        allow(manufacturer).to receive(:components) { [2, 2, 2] }
        expect(manufacturer.autocomplete_hash_priority).to eq(100)
      end
    end
  end

  describe "import csv" do
    it "adds manufacturers to the list" do
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
      expect {
        Manufacturer.import(import_file)
      }.to change(Manufacturer, :count).by(2)
    end

    it "adds in all the attributes that are listed" do
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      manufacturer = Manufacturer.find_by_slug("surly")
      expect(manufacturer.website).to eq("http://surlybikes.com")
      expect(manufacturer.frame_maker).to be_truthy
      expect(manufacturer.open_year).to eq(1900)
      expect(manufacturer.close_year).to eq(3000)
      manufacturer2 = Manufacturer.find_by_slug("wethepeople")
      expect(manufacturer2.website).to eq("http://wethepeople.com")
    end

    it "updates attributes on a second upload" do
      import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import.csv")
      Manufacturer.import(import_file)
      second_import_file = File.open(Rails.root.to_s + "/spec/fixtures/manufacturer-test-import-second.csv")
      Manufacturer.import(second_import_file)
      expect(Manufacturer.find_by_slug("surly")).to be_present
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
        # NOTE: this only seems to fail on the mac version of nokogiri, see PR#2366
        expect(Manufacturer.calculated_mnfg_name(manufacturer_other, malicious_str)).to eq target
      end
    end

    context "manufacturer with parens" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "SE Racing (S E Bikes)") }
      it "returns Just SE Bikes (and does it on save)" do
        expect(Manufacturer.calculated_mnfg_name(manufacturer, nil)).to eq "SE Racing"
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

    it "empties if no logo" do
      manufacturer = Manufacturer.new(logo_source: "something cool")
      manufacturer.set_calculated_attributes
      expect(manufacturer.logo_source).to be_nil
    end
  end
end
