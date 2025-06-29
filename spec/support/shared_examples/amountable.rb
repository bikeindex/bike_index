require "rails_helper"

RSpec.shared_examples "amountable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }

  describe "amount_to_cents" do
    it "returns amount_cents" do
      expect(Amountable.to_cents(12)).to eq 1200
      expect(Amountable.to_cents(12.01)).to eq 1201
    end

    it "returns nil" do
      expect(Amountable.to_cents(nil)).to be_nil
      expect(Amountable.to_cents(" ")).to be_nil
    end

    it "returns amount cents rounded" do
      expect(Amountable.to_cents(12.001)).to eq 1200
      expect(Amountable.to_cents(1200.005)).to eq 120001
      expect(Amountable.to_cents(0.01)).to eq 1
      expect(Amountable.to_cents(0.00001)).to eq 0
    end
  end

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
