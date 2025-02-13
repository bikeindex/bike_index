require "rails_helper"

RSpec.describe Stripe::UpdatePricesJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    it "creates the prices once" do
      VCR.use_cassette("stripe-update_prices_job", match_requests_on: [:path]) do
        expect {
          instance.perform
        }.to change(StripePrice, :count).by(18)

        expect {
          instance.perform
        }.to change(StripePrice, :count).by(0)
      end
    end
  end
end
