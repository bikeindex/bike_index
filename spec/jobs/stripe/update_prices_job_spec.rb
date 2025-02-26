require "rails_helper"

RSpec.describe Stripe::UpdatePricesJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let(:target_basic) { {live?: false, stripe_id: "price_0Qs5p2m0T0GBfX0vhLrGLAAi"} }

    it "creates the prices once" do
      VCR.use_cassette("stripe-update_prices_job", match_requests_on: [:path]) do
        expect {
          instance.perform
        }.to change(StripePrice, :count).by(18)

        expect {
          instance.perform
        }.to change(StripePrice, :count).by(0)

        expect(StripePrice.monthly.basic.count).to eq 3

        expect(StripePrice.monthly.basic.usd.first)
          .to match_hash_indifferently target_basic
      end
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
