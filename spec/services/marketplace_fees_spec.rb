require "rails_helper"

RSpec.describe MarketplaceFees do
  describe "calculate" do
    let(:fees) { MarketplaceFees.calculate(item_amount_cents:, shipping_amount_cents:, boxing_amount_cents:, currency:) }
    let(:item_amount_cents) { 500_00 }
    let(:shipping_amount_cents) { 90_00 }
    let(:boxing_amount_cents) { 75_00 }
    let(:currency) { nil }
    let(:shares_cents) { fees.values_at(:seller_payout_cents, :shop_payout_cents, :shipping_cost_cents, :bike_index_cents) }

    it "adds the processing fee to the buyer's total and takes 9% of that total from the seller" do
      # 3% of $665 is $19.95, plus 30¢. 9% of $685.25 is $61.6725
      expect(fees).to eq({
        currency: :usd,
        item_amount_cents: 500_00,
        shipping_amount_cents: 90_00,
        boxing_amount_cents: 75_00,
        processing_fee_cents: 20_25,
        buyer_total_cents: 685_25,
        platform_fee_cents: 61_67,
        seller_payout_cents: 438_33,
        shop_payout_cents: 75_00,
        shipping_cost_cents: 90_00,
        bike_index_cents: 81_92
      })
      expect(shares_cents.sum).to eq fees[:buyer_total_cents]
    end

    context "above the cap" do
      let(:item_amount_cents) { 1_000_00 }

      it "caps the platform fee at $69 and still charges the full processing fee" do
        expect(fees).to include(processing_fee_cents: 35_25, buyer_total_cents: 1_200_25, platform_fee_cents: 69_00,
          seller_payout_cents: 931_00, bike_index_cents: 104_25)
        expect(shares_cents.sum).to eq fees[:buyer_total_cents]
      end
    end

    context "at the cap" do
      let(:shipping_amount_cents) { 0 }
      let(:boxing_amount_cents) { 0 }

      context "one cent of fee below it" do
        let(:item_amount_cents) { 743_99 }

        it "charges the uncapped fee" do
          # 9% of $766.61 is $68.9949
          expect(fees).to include(buyer_total_cents: 766_61, platform_fee_cents: 68_99, seller_payout_cents: 675_00)
        end
      end

      context "where 9% rounds up to it" do
        let(:item_amount_cents) { 744_00 }

        it "charges exactly the cap" do
          expect(fees).to include(buyer_total_cents: 766_62, platform_fee_cents: 69_00, seller_payout_cents: 675_00)
        end
      end
    end

    context "rounding" do
      let(:shipping_amount_cents) { 0 }
      let(:boxing_amount_cents) { 0 }

      context "a processing fee landing on half a cent" do
        let(:item_amount_cents) { 123_50 }

        it "rounds it up" do
          # 3% of $123.50 is $3.705
          expect(fees).to include(processing_fee_cents: 4_01, buyer_total_cents: 127_51, platform_fee_cents: 11_48)
        end
      end

      context "a processing fee below half a cent" do
        let(:item_amount_cents) { 123_45 }

        it "rounds it down" do
          # 3% of $123.45 is $3.7035; 9% of $127.45 is $11.4705
          expect(fees).to include(processing_fee_cents: 4_00, buyer_total_cents: 127_45, platform_fee_cents: 11_47)
        end
      end

      context "a platform fee landing on half a cent" do
        let(:item_amount_cents) { 122_52 }

        it "rounds it up" do
          # 9% of $126.50 is $11.385
          expect(fees).to include(processing_fee_cents: 3_98, buyer_total_cents: 126_50, platform_fee_cents: 11_39,
            seller_payout_cents: 111_13)
          expect(shares_cents.sum).to eq fees[:buyer_total_cents]
        end
      end
    end

    context "zero shipping and boxing" do
      let(:shipping_amount_cents) { 0 }
      let(:boxing_amount_cents) { 0 }

      it "charges fees on the item alone" do
        expect(fees).to eq({
          currency: :usd,
          item_amount_cents: 500_00,
          shipping_amount_cents: 0,
          boxing_amount_cents: 0,
          processing_fee_cents: 15_30,
          buyer_total_cents: 515_30,
          platform_fee_cents: 46_38,
          seller_payout_cents: 453_62,
          shop_payout_cents: 0,
          shipping_cost_cents: 0,
          bike_index_cents: 61_68
        })
      end

      context "passed as nil" do
        let(:shipping_amount_cents) { nil }
        let(:boxing_amount_cents) { nil }

        it "treats them as zero" do
          expect(fees).to include(shipping_amount_cents: 0, boxing_amount_cents: 0, buyer_total_cents: 515_30,
            platform_fee_cents: 46_38)
        end
      end

      context "left out" do
        it "treats them as zero" do
          expect(MarketplaceFees.calculate(item_amount_cents:)).to eq fees
        end
      end
    end

    context "currency" do
      context "cad" do
        let(:currency) { "CAD" }
        let(:item_amount_cents) { 1_000_00 }

        it "uses the same rates and the same cap, unconverted" do
          expect(fees).to include(currency: :cad, buyer_total_cents: 1_200_25, platform_fee_cents: 69_00)
        end
      end

      context "passed as a symbol" do
        let(:currency) { :eur }

        it "keeps the currency" do
          expect(fees).to include(currency: :eur, buyer_total_cents: 685_25, platform_fee_cents: 61_67)
        end
      end

      context "unknown" do
        let(:currency) { "xyz" }

        it "raises rather than charging in dollars" do
          expect { fees }.to raise_error(ArgumentError, /currency/)
        end
      end
    end

    context "a negative amount" do
      let(:shipping_amount_cents) { -1 }

      it "raises" do
        expect { fees }.to raise_error(ArgumentError, /negative/)
      end
    end
  end
end
