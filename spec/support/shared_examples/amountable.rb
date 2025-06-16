require "rails_helper"

RSpec.shared_examples "amountable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }

  describe "amount_formatted" do
    context "nil" do
      it "returns 0" do
        expect(FactoryBot.build(model_sym, amount_cents: nil).amount_formatted).to eq "$0.00"
      end
    end
  end

  describe "amount_with_nil" do
    context "nil" do
      it "returns 0" do
        expect(FactoryBot.build(model_sym, amount_cents: nil).amount_with_nil).to be_blank
        expect(FactoryBot.build(model_sym, amount_cents: nil).amount).to eq 0
      end
    end

    context "update to nil" do
      let(:instance) { FactoryBot.build(model_sym, amount_cents: 100) }

      it "updates to 0" do
        instance.amount_with_nil = ""
        expect(instance.amount_cents).to be_nil
      end
    end
  end
end
