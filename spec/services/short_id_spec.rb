require "rails_helper"

RSpec.describe ShortId do
  describe "encode" do
    it "returns the type-prefixed base36 id, grouped in threes" do
      expect(ShortId.encode(:bike, 3431156)).to eq "r/21J-HW"
      expect(ShortId.encode(:bike_version, 3431156)).to eq "v/21J-HW"
      expect(ShortId.encode(:marketplace_listing, 3431156)).to eq "m/21J-HW"
      expect(ShortId.encode(:bike, nil)).to be_nil
    end
  end

  describe "decode" do
    it "ignores the prefix, its separator, other separators, and case" do
      ["r/21J-HW", "R/21JHW", "r/21J HW", "r/21J+HW", "r-21JHW", "r21jhw", "21J-HW", "21jhw"].each do |str|
        expect(ShortId.decode(:bike, str)).to eq 3431156
      end
    end
    it "leaves plain-digit params as decimal ids" do
      expect(ShortId.decode(:bike, "123")).to eq "123"
      expect(ShortId.decode(:bike, 123)).to eq "123"
    end
  end
end
