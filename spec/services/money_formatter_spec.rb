require "rails_helper"

RSpec.describe MoneyFormatter do
  describe "money_format" do
    it "formats" do
      expect(described_class.money_format(500)).to eq "$5.00"
    end
    context "passed currency_name" do
      it "formats" do
        expect(described_class.money_format(500, "EUR")).to eq "€5.00"
      end
    end
    context "passed currency euro" do
      it "formats" do
        expect(described_class.money_format(500, Currency.new(:eur))).to eq "€5.00"
      end
    end
    context "passed currency cad" do
      it "formats" do
        expect(described_class.money_format(500, Currency.new(:cad))).to eq "$5.00"
      end
    end
  end

  describe "money_format_no_cents_if_whole" do
    it "drops only whole cents" do
      expect(described_class.money_format_no_cents_if_whole(1500)).to eq "$15"
      expect(described_class.money_format_no_cents_if_whole(999, "EUR")).to eq "€9.99"
    end
  end
end
