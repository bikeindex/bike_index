require "spec_helper"

RSpec.shared_examples 'amountable' do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }
  describe "amount_formatted" do
    context "nil" do
      it "returns 0" do
        expect(FactoryBot.build(model_sym, amount_cents: nil).amount_formatted).to eq "$0.00"
      end
    end
  end
end
