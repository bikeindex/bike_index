# frozen_string_literal: true

require "spec_helper"

RSpec.describe BinxUtils::InputNormalizer do
  describe "boolean" do
    context "1" do
      it "returns true" do
        expect(BinxUtils::InputNormalizer.boolean(1)).to eq true
        expect(BinxUtils::InputNormalizer.boolean(" 1")).to eq true
      end
    end
    context "string" do
      it "returns true" do
        expect(BinxUtils::InputNormalizer.boolean("something")).to eq true
        expect(BinxUtils::InputNormalizer.boolean(" Other Stuffff")).to eq true
      end
    end
    context "true" do
      it "returns true" do
        expect(BinxUtils::InputNormalizer.boolean(true)).to eq true
        expect(BinxUtils::InputNormalizer.boolean("true ")).to eq true
      end
    end
    context "nil" do
      it "returns false" do
        expect(BinxUtils::InputNormalizer.boolean).to eq false
        expect(BinxUtils::InputNormalizer.boolean(nil)).to eq false
      end
    end
    context "false" do
      it "returns false" do
        expect(BinxUtils::InputNormalizer.boolean(false)).to eq false
        expect(BinxUtils::InputNormalizer.boolean("false\n")).to eq false
      end
    end
  end

  describe "present_or_false?" do
    it "is true for false values" do
      expect(false.present?).to be_falsey
      expect(BinxUtils::InputNormalizer.present_or_false?(false)).to eq true
      expect(BinxUtils::InputNormalizer.present_or_false?("false\n")).to eq true
      expect(BinxUtils::InputNormalizer.present_or_false?("0\n")).to eq true
      expect(BinxUtils::InputNormalizer.present_or_false?(0)).to eq true
    end
    it "is false for blank" do
      expect(BinxUtils::InputNormalizer.present_or_false?(nil)).to eq false
      expect(BinxUtils::InputNormalizer.present_or_false?("")).to eq false
      expect(BinxUtils::InputNormalizer.present_or_false?("   \n")).to eq false
    end
    it "is true for strings" do
      expect(BinxUtils::InputNormalizer.present_or_false?("something")).to eq true
      expect(BinxUtils::InputNormalizer.present_or_false?(true)).to eq true
      expect(BinxUtils::InputNormalizer.present_or_false?(3)).to eq true
    end
  end

  describe "string" do
    it "returns nil for blank" do
      expect(BinxUtils::InputNormalizer.string(nil)).to be_nil
      expect(BinxUtils::InputNormalizer.string("")).to be_nil
      expect(BinxUtils::InputNormalizer.string("   ")).to be_nil
    end
    it "strips and removes extra spaces" do
      expect(BinxUtils::InputNormalizer.string(" D  ")).to eq "D"
      expect(BinxUtils::InputNormalizer.string(" D HI \Z \nf ")).to eq "D HI \Z f"
    end
  end

  describe "regex_escape" do
    it "is nil for blank" do
      expect(BinxUtils::InputNormalizer.string(" ")).to be_nil
    end
    it "replaces" do
      expect(BinxUtils::InputNormalizer.regex_escape("(((..{?}")).to eq "........"
    end
  end

  describe "sanitize" do
    it "is empty string for nil" do
      expect(BinxUtils::InputNormalizer.sanitize).to eq ""
      expect(BinxUtils::InputNormalizer.sanitize(nil)).to eq ""
      expect(BinxUtils::InputNormalizer.sanitize("\n\n")).to eq ""
    end
    it "is string for boolean" do
      expect(BinxUtils::InputNormalizer.sanitize(true)).to eq "true"
      expect(BinxUtils::InputNormalizer.sanitize(false)).to eq "false"
      expect(BinxUtils::InputNormalizer.sanitize(" true")).to eq "true"
    end
    it "is strings for numbers" do
      expect(BinxUtils::InputNormalizer.sanitize(5)).to eq "5"
      expect(BinxUtils::InputNormalizer.sanitize(5_000)).to eq "5000"
      expect(BinxUtils::InputNormalizer.sanitize(" 5000 ")).to eq "5000"
      expect(BinxUtils::InputNormalizer.sanitize(5.000)).to eq "5.0"
      expect(BinxUtils::InputNormalizer.sanitize(BigDecimal(0))).to eq "0.0"
    end
    it "doesn't remove text but does remove whitespace" do
      expect(BinxUtils::InputNormalizer.sanitize("Some cool text ")).to eq "Some cool text"
      expect(BinxUtils::InputNormalizer.sanitize(" Some \tcool \ntext")).to eq "Some cool text"
    end
    it "strips html tags" do
      expect(BinxUtils::InputNormalizer.sanitize("<b>Hello</b> Plus other things</a>")).to eq "Hello Plus other things"
      expect(BinxUtils::InputNormalizer.sanitize("<div><b>Hello</b> Plus other </div>things</a>")).to eq "Hello Plus other things"
    end
    it "strips out script" do
      expect(BinxUtils::InputNormalizer.sanitize("<script>alert();</script>")).to eq ""
      expect(BinxUtils::InputNormalizer.sanitize("<b>Hello</b><script>alert()</script>")).to eq "Hello"
      expect(BinxUtils::InputNormalizer.sanitize('<b class="something">Hello</b><script>alert()</script>\\')).to eq "Hello\\"
    end
    it "returns bare ampersands" do
      expect(BinxUtils::InputNormalizer.sanitize("Bike & Ski")).to eq "Bike & Ski"
      expect(BinxUtils::InputNormalizer.sanitize("Bike &amp; Ski")).to eq "Bike & Ski"
    end
    it "leaves useful special characters" do
      expect(BinxUtils::InputNormalizer.sanitize("Bike ())( /// Ski ")).to eq "Bike ())( /// Ski"
      expect(BinxUtils::InputNormalizer.sanitize(' Bike [[] \\\ Ski ')).to eq 'Bike [[] \\\ Ski'
      expect(BinxUtils::InputNormalizer.sanitize("Surly's Cross-check bike")).to eq "Surly's Cross-check bike"
    end
    it "leaves accents" do
      expect(BinxUtils::InputNormalizer.sanitize("paké")).to eq "paké"
    end
    it "leaves emojis" do
      expect(BinxUtils::InputNormalizer.sanitize("🧹")).to eq "🧹"
    end
    it "removes angle brackets" do
      expect(BinxUtils::InputNormalizer.sanitize("Bike < Ski")).to eq "Bike &lt; Ski"
      expect(BinxUtils::InputNormalizer.sanitize("Bike &lt; Ski")).to eq "Bike &lt; Ski"
      expect(BinxUtils::InputNormalizer.sanitize("Bike > Ski")).to eq "Bike &gt; Ski"
      expect(BinxUtils::InputNormalizer.sanitize("Bike &gt; Ski")).to eq "Bike &gt; Ski"
      expect(BinxUtils::InputNormalizer.sanitize("Bike <> Ski")).to eq "Bike &lt;&gt; Ski"
      expect(BinxUtils::InputNormalizer.sanitize("Bike &lt;&gt; Ski")).to eq "Bike &lt;&gt; Ski"
    end
  end
end
