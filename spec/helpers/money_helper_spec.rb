# coding: utf-8
require "rails_helper"

RSpec.describe MoneyHelper, type: :helper do
  describe "#default_currency" do
    context "given the current locale is set to the default_locale (en)" do
      it "returns the alphabetic_code USD" do
        expect(default_currency).to eq("USD")
      end
    end

    context "given the current locale is set to an available locale" do
      it "returns the alphabetic_code for the locale's currency" do
        I18n.with_locale(:nl) do
          expect(default_currency).to eq("EUR")
        end
      end
    end

    context "given the current locale is set to a locale with a fallback" do
      it "returns the alphabetic_code for the fallback locale's currency" do
        I18n.with_locale(:"en-GB") do
          expect(default_currency).to eq("GBP")
        end
      end
    end

    context "given the current locale is set to an unavailable locale" do
      it "returns the alphabetic_code for the default locale's currency" do
        I18n.with_locale(:"unavailable") do
          expect { default_currency }.to raise_error(I18n::MissingTranslationData)
        end
      end
    end
  end

  describe "#money_usd" do
    before do
      FactoryBot.create(:exchange_rate_to_eur)
    end

    context "given a valid target currency" do
      it "returns a Money object converting to the target currency" do
        conversion_rate = Money.default_bank.get_rate(:USD, :EUR)
        currency = money_usd(1.00, exchange_to: :EUR)
        expect(currency).to be_an_instance_of(Money)
        expect(currency.fractional).to eq(conversion_rate * 100)
        expect(currency.currency).to eq(:EUR)
      end
    end

    context "given an invalid target currency" do
      it "raises UnknownCurrency" do
        expect { money_usd(1.00, exchange_to: :ERR) }
          .to(raise_error(Money::Currency::UnknownCurrency))
      end
    end

    context "given an unknown exchange rate" do
      it "raises UnknownRate" do
        expect { money_usd(1.00, exchange_to: :CAD) }
          .to(raise_error(Money::Bank::UnknownRate))
      end
    end

    context "given no target currency" do
      it "returns a Money object converting to the default currency" do
        currency = money_usd(1.00)
        expect(currency).to be_an_instance_of(Money)
        expect(currency.fractional).to eq(100)
        expect(currency.currency).to eq(:USD)
      end
    end
  end

  describe "#as_currency" do
    before do
      FactoryBot.create(:exchange_rate_to_eur)
    end

    context "given a valid target currency" do
      it "returns a Money object converting to the default currency" do
        expect(as_currency(100, exchange_to: :EUR)).to eq("€88")
      end
    end

    context "given an invalid target currency" do
      it "raises UnknownCurrency" do
        expect { as_currency(100, exchange_to: :ERR) }
          .to(raise_error(Money::Currency::UnknownCurrency))
      end
    end

    context "given an unknown exchange rate" do
      it "raises UnknownRate" do
        expect { as_currency(1.00, exchange_to: :CAD) }
          .to(raise_error(Money::Bank::UnknownRate))
      end
    end

    context "given no target currency" do
      it "returns a Money object converting to the default currency" do
        expect(as_currency(100)).to eq("$100")
      end
    end
  end
end
