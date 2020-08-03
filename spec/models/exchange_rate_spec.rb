# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExchangeRate, type: :model do
  describe "validations" do
    before { expect(ExchangeRate.count).to eq 0 }
    it "ensures rate is non-negative" do
      rate = FactoryBot.build(:exchange_rate, rate: -1)
      expect(rate).to be_invalid
      rate.rate = 1.4
      expect(rate).to be_valid
    end

    it "ensures all fields are present" do
      rate = FactoryBot.build(:exchange_rate, rate: nil)
      expect(rate).to be_invalid
      rate = FactoryBot.build(:exchange_rate, from: nil)
      expect(rate).to be_invalid
      rate = FactoryBot.build(:exchange_rate, to: nil)
      expect(rate).to be_invalid
      rate = FactoryBot.build(:exchange_rate)
      expect(rate).to be_valid
    end

    it "ensures currencies are ISO-formatted, case-insensitively" do
      rate = FactoryBot.build(:exchange_rate, from: "us", to: "eu")
      expect(rate).to be_invalid

      rate.from = "usd"
      rate.to = "eur"

      expect(rate).to be_valid
    end

    it "ensures currencies are pairwise unique" do
      rate0 = FactoryBot.create(:exchange_rate)
      rate1 = FactoryBot.build(:exchange_rate, from: rate0.from, to: rate0.to)
      expect(rate1).to be_invalid
      rate1.to = rate1.to.reverse
      expect(rate1).to be_valid
    end

    it "prevents deleting a rate required for i18n" do
      allow(ExchangeRate).to receive(:required_targets).and_return(["USD", "EUR"])

      rate1 = FactoryBot.create(:exchange_rate_to_eur)
      expect(rate1.to).to be_in(ExchangeRate.required_targets)
      expect { rate1.destroy }.to_not(change { ExchangeRate.count })

      rate2 = FactoryBot.create(:exchange_rate, to: "CAD")
      expect(rate2.to).to_not be_in(ExchangeRate.required_targets)
      expect { rate2.destroy }.to(change { ExchangeRate.count }.by(-1))
    end
  end

  describe ".add_rate" do
    context "given a found exchange rate" do
      it "updates the exchange rate multiplier" do
        rate = FactoryBot.create(:exchange_rate, rate: 0.55)
        expect(rate.rate).to eq(0.55)
        found_rate = ExchangeRate.add_rate(rate.from, rate.to, 1.95)
        expect(found_rate).to eq(rate)
        expect(found_rate.rate).to eq(1.95)
      end
    end

    context "given an absent exchange rate" do
      it "creates the exchange rate" do
        multiplier = ExchangeRate.get_rate("USD", "EUR")
        expect(multiplier).to be_nil
      end
    end
  end

  describe ".get_rate" do
    context "given a found exchange rate" do
      it "returns the rate multiplier for the given exchange rate" do
        rate = FactoryBot.create(:exchange_rate, rate: 0.55)
        multiplier = ExchangeRate.get_rate(rate.from, rate.to)
        expect(multiplier).to eq(0.55)
      end
    end

    context "given an absent exchange rate" do
      it "returns nil" do
        expect(ExchangeRate.count).to be_zero
        found_rate = ExchangeRate.add_rate("USD", "EUR", 1.95)
        expect(found_rate.rate).to eq(1.95)
        expect(ExchangeRate.count).to eq(1)
      end
    end
  end
end
