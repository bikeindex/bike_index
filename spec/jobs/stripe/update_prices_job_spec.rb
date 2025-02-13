require "rails_helper"

RSpec.describe UpdatePricesJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    it "creates the prices once" do
      expect {
        instance.perform
      }.to change(StripePrice, :count).by(18)

      expect {
        instance.perform
      }.to change(StripePrice, :count).by(0)
    end
  end
end
