require "rails_helper"

RSpec.describe ParamsNormalizer do
  describe "boolean" do
    context "1" do
      it "returns true" do
        expect(ParamsNormalizer.boolean(1)).to eq true
        expect(ParamsNormalizer.boolean(" 1")).to eq true
      end
    end
    context "true" do
      it "returns true" do
        expect(ParamsNormalizer.boolean(true)).to eq true
        expect(ParamsNormalizer.boolean("true ")).to eq true
      end
    end
    context "nil" do
      it "returns false" do
        expect(ParamsNormalizer.boolean).to eq false
        expect(ParamsNormalizer.boolean(nil)).to eq false
      end
    end
    context "false" do
      it "returns false" do
        expect(ParamsNormalizer.boolean(false)).to eq false
        expect(ParamsNormalizer.boolean("false\n")).to eq false
      end
    end
  end
end
