require "rails_helper"

RSpec.describe Currency, type: :model do
  describe "friendly_find" do
    it "returns nil for not found" do
      expect(Currency.friendly_find(" ")).to be_nil
      expect(Currency.friendly_find("xxx")).to be_nil
    end
  end

  describe "USD" do
    let(:slug) { :usd }
    let(:target) { {name: "USD", symbol: "$", slug:} }
    it "creates with slug" do
      expect(Currency.new(slug)).to have_attributes(target)
    end
    it "creates with name" do
      expect(Currency.new("USD")).to have_attributes(target)
    end
    it "creates from default" do
      expect(Currency.default).to have_attributes(target)
    end
    it "creates from symbol" do
      expect(Currency.new("$")).to have_attributes(target)
    end
  end

  describe "CAD" do
    let(:slug) { :cad }
    let(:target) { {name: "CAD", symbol: "$", slug:} }

    it "creates with slug" do
      expect(Currency.new(slug)).to have_attributes(target)
    end

    it "creates with name" do
      expect(Currency.new("CAD")).to have_attributes(target)
    end

    it "creates from instance" do
      instance = Currency.new(slug)
      expect(Currency.new(instance)).to have_attributes(target)
    end
  end

  describe "EUR" do
    let(:slug) { :eur }
    let(:target) { {name: "EUR", symbol: "€", slug:} }

    it "creates with slug" do
      expect(Currency.new(slug)).to have_attributes(target)
    end

    it "creates with name" do
      expect(Currency.new("EUR")).to have_attributes(target)
    end

    it "creates with symbol" do
      expect(Currency.new("€")).to have_attributes(target)
    end
  end

  describe "select_option" do
    let(:instance) { Currency.new(:cad) }
    let(:target) { "$ (CAD)" }
    it "returns target" do
      expect(instance.select_option).to eq target
      expect(described_class.select_options).to include([target, instance.slug.to_s])
    end
  end
end
