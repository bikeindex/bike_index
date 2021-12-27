require "rails_helper"

RSpec.describe ParamsNormalizer do
  describe "boolean" do
    context "1" do
      it "returns true" do
        expect(ParamsNormalizer.boolean(1)).to eq true
        expect(ParamsNormalizer.boolean(" 1")).to eq true
      end
    end
    context "string" do
      it "returns true" do
        expect(ParamsNormalizer.boolean("something")).to eq true
        expect(ParamsNormalizer.boolean(" Other Stuffff")).to eq true
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

  describe "present_or_false?" do
    it "is true for false values" do
      expect(false.present?).to be_falsey # This is the problem!
      expect(ParamsNormalizer.present_or_false?(false)).to eq true
      expect(ParamsNormalizer.present_or_false?("false\n")).to eq true
      expect(ParamsNormalizer.present_or_false?("0\n")).to eq true
      expect(ParamsNormalizer.present_or_false?(0)).to eq true
    end
    it "is false for blank" do
      expect(ParamsNormalizer.present_or_false?(nil)).to eq false
      expect(ParamsNormalizer.present_or_false?("")).to eq false
      expect(ParamsNormalizer.present_or_false?("   \n")).to eq false
    end
    it "is true for strings" do
      expect(ParamsNormalizer.present_or_false?("something")).to eq true
      expect(ParamsNormalizer.present_or_false?(true)).to eq true
      expect(ParamsNormalizer.present_or_false?(3)).to eq true
    end
  end
end
