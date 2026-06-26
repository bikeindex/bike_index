require "rails_helper"

RSpec.describe ShortId do
  describe "encode" do
    it "returns the upcased base36 id" do
      expect(ShortId.encode(1000000)).to eq "LFLS"
      expect(ShortId.encode(nil)).to be_nil
    end
  end

  describe "decode" do
    it "decodes a base36 short_id, case insensitively" do
      expect(ShortId.decode("LFLS")).to eq 1000000
      expect(ShortId.decode("lfls")).to eq 1000000
    end
    it "leaves plain-digit params as decimal ids" do
      expect(ShortId.decode("123")).to eq "123"
      expect(ShortId.decode(123)).to eq "123"
    end
  end
end
