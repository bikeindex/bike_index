require "rails_helper"

RSpec.describe StripePrice, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"

  describe "factory" do
    let(:stripe_price) { FactoryBot.create(:stripe_price) }
    it "is valid" do
      expect(stripe_price).to be_valid
    end
    describe "stripe_price_basic" do
      let(:stripe_price) { FactoryBot.create(:stripe_price_basic) }
      it "has the actual stripe_id" do
        expect(stripe_price).to be_valid
        expect(stripe_price.stripe_id).to eq "price_0URHtsm0T0GBfX0vxXWA0L8a"
        expect(StripePrice.count).to eq 1
        # It returns the existing stripe_price
        expect(FactoryBot.create(:stripe_price_basic).id).to eq stripe_price.id
        expect(StripePrice.count).to eq 1
      end
    end
  end

  describe "active_for" do
    include_context :active_stripe_prices
    let(:cad) { Currency.new("cad") }
    let!(:cad_stripe_prices) do
      stripe_prices.map do |stripe_price|
        FactoryBot.create(:stripe_price, stripe_price.slice(:membership_level, :interval, :amount_cents).merge(currency_enum: "cad"))
      end
    end
    before { FactoryBot.create(:stripe_price_basic_archived) }

    it "returns the currency's active prices" do
      expect(StripePrice.active_for(Currency.default)).to match_array stripe_prices
      expect(StripePrice.active_for(cad)).to match_array cad_stripe_prices
    end

    context "with a CAD price inactive" do
      before { cad_stripe_prices.last.update(active: false) }

      it "falls back to the default currency" do
        expect(StripePrice.active_for(cad)).to match_array stripe_prices
      end
    end
  end
end
