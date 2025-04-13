require "rails_helper"

RSpec.shared_examples "simple_nameable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }

  describe "simple_name" do
    let(:instance) { FactoryBot.build(model_sym, name:) }
    let(:name) { "Some Name" }
    it "returns name" do
      expect(instance.simple_name).to eq name
      expect(instance.secondary_name).to be_nil
    end

    context "with parens" do
      let(:name) { "Some name (Extra name)" }
      it "finds by the name" do
        expect(instance.simple_name).to eq "Some name"
        expect(instance.secondary_name).to eq "Extra name"
      end
    end
  end
end
