require "rails_helper"

RSpec.describe MarketplaceFees do
  describe "calculate" do
    let(:fees) { MarketplaceFees.calculate(item_amount_cents:, shipping_amount_cents:, boxing_amount_cents:, currency:) }
    let(:item_amount_cents) { 500_00 }
    let(:shipping_amount_cents) { 90_00 }
    let(:boxing_amount_cents) { 75_00 }
    let(:currency) { nil }
    let(:shares_cents) { fees.values_at(:seller_payout_cents, :shop_payout_cents, :shipping_cost_cents, :bike_index_cents) }

    it "takes 9% of the item from the seller and adds 3% of everything to the buyer's total" do
      # 9% of $500 is $45. 3% of $665 is $19.95
      expect(fees).to eq({
        currency: :usd,
        item_amount_cents: 500_00,
        shipping_amount_cents: 90_00,
        boxing_amount_cents: 75_00,
        processing_fee_cents: 19_95,
        buyer_total_cents: 684_95,
        platform_fee_cents: 45_00,
        seller_payout_cents: 455_00,
        shop_payout_cents: 75_00,
        shipping_cost_cents: 90_00,
        bike_index_cents: 64_95
      })
      expect(shares_cents.sum).to eq fees[:buyer_total_cents]
    end

    context "a cheap item with shipping larger than the item" do
      let(:item_amount_cents) { 20_00 }
      let(:shipping_amount_cents) { 150_00 }

      it "leaves the seller a positive payout" do
        # 9% of $20 is $1.80. 3% of $245 is $7.35
        expect(fees).to eq({
          currency: :usd,
          item_amount_cents: 20_00,
          shipping_amount_cents: 150_00,
          boxing_amount_cents: 75_00,
          processing_fee_cents: 7_35,
          buyer_total_cents: 252_35,
          platform_fee_cents: 1_80,
          seller_payout_cents: 18_20,
          shop_payout_cents: 75_00,
          shipping_cost_cents: 150_00,
          bike_index_cents: 9_15
        })
        expect(shares_cents.sum).to eq fees[:buyer_total_cents]
      end
    end

    context "above the cap" do
      let(:item_amount_cents) { 1_000_00 }

      it "caps the platform fee at $69 and still charges the full processing fee" do
        # 3% of $1,165 is $34.95
        expect(fees).to eq({
          currency: :usd,
          item_amount_cents: 1_000_00,
          shipping_amount_cents: 90_00,
          boxing_amount_cents: 75_00,
          processing_fee_cents: 34_95,
          buyer_total_cents: 1_199_95,
          platform_fee_cents: 69_00,
          seller_payout_cents: 931_00,
          shop_payout_cents: 75_00,
          shipping_cost_cents: 90_00,
          bike_index_cents: 103_95
        })
        expect(shares_cents.sum).to eq fees[:buyer_total_cents]
      end
    end

    context "at the cap" do
      let(:shipping_amount_cents) { 0 }
      let(:boxing_amount_cents) { 0 }

      context "one cent of fee below it" do
        let(:item_amount_cents) { 766_61 }

        it "charges the uncapped fee" do
          # 9% of $766.61 is $68.9949. 3% of $766.61 is $22.9983
          expect(fees).to eq({
            currency: :usd,
            item_amount_cents: 766_61,
            shipping_amount_cents: 0,
            boxing_amount_cents: 0,
            processing_fee_cents: 23_00,
            buyer_total_cents: 789_61,
            platform_fee_cents: 68_99,
            seller_payout_cents: 697_62,
            shop_payout_cents: 0,
            shipping_cost_cents: 0,
            bike_index_cents: 91_99
          })
        end
      end

      context "where 9% rounds up to it" do
        let(:item_amount_cents) { 766_62 }

        it "charges exactly the cap" do
          # 9% of $766.62 is $68.9958
          expect(fees).to eq({
            currency: :usd,
            item_amount_cents: 766_62,
            shipping_amount_cents: 0,
            boxing_amount_cents: 0,
            processing_fee_cents: 23_00,
            buyer_total_cents: 789_62,
            platform_fee_cents: 69_00,
            seller_payout_cents: 697_62,
            shop_payout_cents: 0,
            shipping_cost_cents: 0,
            bike_index_cents: 92_00
          })
        end
      end

      context "where 9% passes it" do
        let(:item_amount_cents) { 766_67 }

        it "charges the cap" do
          # 9% of $766.67 is $69.0003. 3% of $766.67 is $23.0001
          expect(fees).to eq({
            currency: :usd,
            item_amount_cents: 766_67,
            shipping_amount_cents: 0,
            boxing_amount_cents: 0,
            processing_fee_cents: 23_00,
            buyer_total_cents: 789_67,
            platform_fee_cents: 69_00,
            seller_payout_cents: 697_67,
            shop_payout_cents: 0,
            shipping_cost_cents: 0,
            bike_index_cents: 92_00
          })
        end
      end
    end

    context "rounding" do
      let(:shipping_amount_cents) { 0 }
      let(:boxing_amount_cents) { 0 }

      context "fees landing on half a cent" do
        let(:item_amount_cents) { 123_50 }

        it "rounds them up" do
          # 3% of $123.50 is $3.705; 9% is $11.115
          expect(fees).to eq({
            currency: :usd,
            item_amount_cents: 123_50,
            shipping_amount_cents: 0,
            boxing_amount_cents: 0,
            processing_fee_cents: 3_71,
            buyer_total_cents: 127_21,
            platform_fee_cents: 11_12,
            seller_payout_cents: 112_38,
            shop_payout_cents: 0,
            shipping_cost_cents: 0,
            bike_index_cents: 14_83
          })
          expect(shares_cents.sum).to eq fees[:buyer_total_cents]
        end
      end

      context "fees below half a cent" do
        let(:item_amount_cents) { 123_45 }

        it "rounds them down" do
          # 3% of $123.45 is $3.7035; 9% is $11.1105
          expect(fees).to eq({
            currency: :usd,
            item_amount_cents: 123_45,
            shipping_amount_cents: 0,
            boxing_amount_cents: 0,
            processing_fee_cents: 3_70,
            buyer_total_cents: 127_15,
            platform_fee_cents: 11_11,
            seller_payout_cents: 112_34,
            shop_payout_cents: 0,
            shipping_cost_cents: 0,
            bike_index_cents: 14_81
          })
          expect(shares_cents.sum).to eq fees[:buyer_total_cents]
        end
      end
    end

    context "zero shipping and boxing" do
      let(:shipping_amount_cents) { 0 }
      let(:boxing_amount_cents) { 0 }
      let(:target_fees) do
        {
          currency: :usd,
          item_amount_cents: 500_00,
          shipping_amount_cents: 0,
          boxing_amount_cents: 0,
          processing_fee_cents: 15_00,
          buyer_total_cents: 515_00,
          platform_fee_cents: 45_00,
          seller_payout_cents: 455_00,
          shop_payout_cents: 0,
          shipping_cost_cents: 0,
          bike_index_cents: 60_00
        }
      end

      it "charges fees on the item alone" do
        expect(fees).to eq target_fees
      end

      context "passed as nil" do
        let(:shipping_amount_cents) { nil }
        let(:boxing_amount_cents) { nil }

        it "treats them as zero" do
          expect(fees).to eq target_fees
        end
      end

      context "left out" do
        it "treats them as zero" do
          expect(MarketplaceFees.calculate(item_amount_cents:)).to eq target_fees
        end
      end
    end

    context "currency" do
      context "cad" do
        let(:currency) { "CAD" }
        let(:item_amount_cents) { 1_000_00 }

        it "uses the same rates and the same cap, unconverted" do
          expect(fees).to eq({
            currency: :cad,
            item_amount_cents: 1_000_00,
            shipping_amount_cents: 90_00,
            boxing_amount_cents: 75_00,
            processing_fee_cents: 34_95,
            buyer_total_cents: 1_199_95,
            platform_fee_cents: 69_00,
            seller_payout_cents: 931_00,
            shop_payout_cents: 75_00,
            shipping_cost_cents: 90_00,
            bike_index_cents: 103_95
          })
        end
      end

      context "passed as a symbol" do
        let(:currency) { :eur }

        it "keeps the currency" do
          expect(fees).to eq({
            currency: :eur,
            item_amount_cents: 500_00,
            shipping_amount_cents: 90_00,
            boxing_amount_cents: 75_00,
            processing_fee_cents: 19_95,
            buyer_total_cents: 684_95,
            platform_fee_cents: 45_00,
            seller_payout_cents: 455_00,
            shop_payout_cents: 75_00,
            shipping_cost_cents: 90_00,
            bike_index_cents: 64_95
          })
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
