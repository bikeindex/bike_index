require "rails_helper"

RSpec.describe InputNormalizer do
  describe "boolean" do
    context "1" do
      it "returns true" do
        expect(InputNormalizer.boolean(1)).to eq true
        expect(InputNormalizer.boolean(" 1")).to eq true
      end
    end
    context "string" do
      it "returns true" do
        expect(InputNormalizer.boolean("something")).to eq true
        expect(InputNormalizer.boolean(" Other Stuffff")).to eq true
      end
    end
    context "true" do
      it "returns true" do
        expect(InputNormalizer.boolean(true)).to eq true
        expect(InputNormalizer.boolean("true ")).to eq true
      end
    end
    context "nil" do
      it "returns false" do
        expect(InputNormalizer.boolean).to eq false
        expect(InputNormalizer.boolean(nil)).to eq false
      end
    end
    context "false" do
      it "returns false" do
        expect(InputNormalizer.boolean(false)).to eq false
        expect(InputNormalizer.boolean("false\n")).to eq false
      end
    end
  end

  describe "present_or_false?" do
    it "is true for false values" do
      expect(false.present?).to be_falsey # This is the problem!
      expect(InputNormalizer.present_or_false?(false)).to eq true
      expect(InputNormalizer.present_or_false?("false\n")).to eq true
      expect(InputNormalizer.present_or_false?("0\n")).to eq true
      expect(InputNormalizer.present_or_false?(0)).to eq true
    end
    it "is false for blank" do
      expect(InputNormalizer.present_or_false?(nil)).to eq false
      expect(InputNormalizer.present_or_false?("")).to eq false
      expect(InputNormalizer.present_or_false?("   \n")).to eq false
    end
    it "is true for strings" do
      expect(InputNormalizer.present_or_false?("something")).to eq true
      expect(InputNormalizer.present_or_false?(true)).to eq true
      expect(InputNormalizer.present_or_false?(3)).to eq true
    end
  end

  describe "string" do
    it "returns nil for blank" do
      expect(InputNormalizer.string(nil)).to be_nil
      expect(InputNormalizer.string("")).to be_nil
      expect(InputNormalizer.string("   ")).to be_nil
    end
    it "strips and removes extra spaces" do
      expect(InputNormalizer.string(" D  ")).to eq "D"
      expect(InputNormalizer.string(" D HI \Z \nf ")).to eq "D HI \Z f"
    end
  end
end
