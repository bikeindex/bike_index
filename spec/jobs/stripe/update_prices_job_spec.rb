require "rails_helper"

RSpec.describe Stripe::UpdatePricesJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:target_basic) { {live?: false, stripe_id: "price_0Qs5p2m0T0GBfX0vhLrGLAAi", active: true} }
    # Accidentally created an incorrect price on production that people bought which was for a year, but was not discounted
    let(:stripe_price_existing) do
      StripePrice.create(stripe_id: "price_0R1BSzm0T0GBfX0vHXryVB6y",
        membership_level: "basic",
        active: true,
        live: true,
        interval: "monthly",
        currency_enum: "cad",
        amount_cents: 69)
    end
    let(:target_existing_updated) do
      {live?: false, active: false, currency_enum: "usd",
       amount_cents: 5999}
    end
    let!(:stripe_price_unknown) { FactoryBot.create(:stripe_price, stripe_id: "xxxxxx", membership_level: "patron") }

    it "creates the prices once" do
      # Starts out active!
      expect(stripe_price_existing).to be_valid
      expect(stripe_price_existing.reload.active?).to be_truthy
      expect(stripe_price_unknown.reload.active).to be_truthy

      VCR.use_cassette("stripe-update_prices_job", match_requests_on: [:path]) do
        expect {
          instance.perform
        }.to change(StripePrice, :count).by(18)

        expect {
          instance.perform
        }.to change(StripePrice, :count).by(0)

        expect(StripePrice.basic.count).to eq 7
        expect(StripePrice.basic.active.count).to eq 6

        expect(StripePrice.monthly.basic.active.count).to eq 3

        expect(StripePrice.monthly.basic.usd.active.first).to match_hash_indifferently target_basic

        expect(stripe_price_existing.reload).to match_hash_indifferently target_existing_updated
      end
      expect(stripe_price_unknown.reload.active).to be_falsey
    end
  end

  describe "product_membership_level" do
    let(:target) do
      {
        "prod_Rld50xInuW3d5A" => :basic,
        "prod_Rld8cRL9WZDT4c" => :plus,
        "prod_Rld9TmkiZwPAi2" => :patron
      }
    end
    it "returns the products with membership kinds" do
      # Use the same cassette as above because it is included in the above call
      VCR.use_cassette("stripe-update_prices_job", match_requests_on: [:path]) do
        expect(instance.send(:product_membership_level)).to eq target
      end
    end
  end
end
