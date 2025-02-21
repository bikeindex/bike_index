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
        expect(stripe_price.stripe_id).to eq 'price_0Qs5p2m0T0GBfX0vhLrGLAAi'
        expect(StripePrice.count).to eq 1
        # It returns the existing stripe_price
        expect(FactoryBot.create(:stripe_price_basic).id).to eq stripe_price.id
        expect(StripePrice.count).to eq 1
      end
    end
  end
end
