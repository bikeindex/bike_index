require "rails_helper"

RSpec.describe HexColor do
  describe "normalize" do
    it "prefixes a hex string" do
      expect(HexColor.normalize(" ee7e2c\t")).to eq "#ee7e2c"
    end

    it "takes the shorthand, and a hex it's already been given" do
      expect(HexColor.normalize("EE7")).to eq "#ee7"
      expect(HexColor.normalize("#ee7e2c")).to eq "#ee7e2c"
    end

    it "is nil for anything that isn't a hex color, so nothing else reaches the style attribute" do
      expect(HexColor.normalize("@user + 1233")).to be_nil
      expect(HexColor.normalize("red; background-image: url(x)")).to be_nil
      expect(HexColor.normalize("ee7e2cff")).to be_nil
      expect(HexColor.normalize(nil)).to be_nil
      expect(HexColor.normalize(" ")).to be_nil
    end
  end
end
