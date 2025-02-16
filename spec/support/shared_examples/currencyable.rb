require "rails_helper"

RSpec.shared_examples "currencyable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance_new) { subject.class.new }

  describe "assigning currency_enum" do
    before { instance_new.currency_enum = :cad }

    it "returns currency" do
      expect(instance_new.currency_name).to eq "CAD"
      expect(instance_new.currency_symbol).to eq "$"
    end
  end

  describe "assigning currency" do
    it "assigns name" do
      instance_new.currency = "EUR"
      expect(instance_new.currency_enum).to eq "eur"
    end

    it "assigns symbol" do
      instance_new.currency = "$"
      expect(instance_new.currency_enum).to eq "usd"
    end

    it "assigns object" do
      instance_new.currency = Currency.new("CAD")
      expect(instance_new.currency_enum).to eq "cad"
    end
  end
end
