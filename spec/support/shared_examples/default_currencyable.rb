require "rails_helper"

RSpec.shared_examples "default_currencyable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.build model_sym }

  describe "currency" do
    it "returns default" do
      expect(instance.currency_symbol).to eq "$"
      expect(instance.currency_name).to eq "USD"
    end
  end
end
