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

  describe "darken" do
    it "keeps the hue and saturation, taking the shade off the lightness" do
      # #ee7e2c is hsl(25, 85%, 55%)
      expect(HexColor.darken("ee7e2c")).to eq "hsla(25, 85%, 47%, 1)"
      expect(HexColor.darken("#016ec2", amount: 0.2)).to eq "hsla(206, 99%, 18%, 1)"
    end

    it "handles the colors with no hue to keep, and doesn't pass black" do
      expect(HexColor.darken("#fff")).to eq "hsla(0, 0%, 92%, 1)"
      expect(HexColor.darken("#000")).to eq "hsla(0, 0%, 0%, 1)"
    end

    it "is nil for anything that isn't a hex color" do
      expect(HexColor.darken("@user + 1233")).to be_nil
      expect(HexColor.darken(nil)).to be_nil
    end
  end

  describe "darken_hex" do
    # The same color the hsla names, for the places that take a hex - the admin
    # recommendation, and the ?button_hover= it recommends writing
    it "is the hex a browser renders the hsla as" do
      expect(HexColor.darken_hex("c9a227")).to eq "#a78820"
      expect(HexColor.darken_hex("#fff")).to eq "#ebebeb"
      expect(HexColor.darken_hex("#000")).to eq "#000000"
    end

    it "is nil for anything that isn't a hex color" do
      expect(HexColor.darken_hex("@user + 1233")).to be_nil
    end
  end
end
