# frozen_string_literal: true

require "spec_helper"

RSpec.describe Binxtils::InputNormalizer do
  describe "boolean" do
    context "1" do
      it "returns true" do
        expect(Binxtils::InputNormalizer.boolean(1)).to eq true
        expect(Binxtils::InputNormalizer.boolean(" 1")).to eq true
      end
    end
    context "string" do
      it "returns true" do
        expect(Binxtils::InputNormalizer.boolean("something")).to eq true
        expect(Binxtils::InputNormalizer.boolean(" Other Stuffff")).to eq true
      end
    end
    context "true" do
      it "returns true" do
        expect(Binxtils::InputNormalizer.boolean(true)).to eq true
        expect(Binxtils::InputNormalizer.boolean("true ")).to eq true
      end
    end
    context "nil" do
      it "returns false" do
        expect(Binxtils::InputNormalizer.boolean).to eq false
        expect(Binxtils::InputNormalizer.boolean(nil)).to eq false
      end
    end
    context "false" do
      it "returns false" do
        expect(Binxtils::InputNormalizer.boolean(false)).to eq false
        expect(Binxtils::InputNormalizer.boolean("false\n")).to eq false
      end
    end
  end

  describe "present_or_false?" do
    it "is true for false values" do
      expect(false.present?).to be_falsey
      expect(Binxtils::InputNormalizer.present_or_false?(false)).to eq true
      expect(Binxtils::InputNormalizer.present_or_false?("false\n")).to eq true
      expect(Binxtils::InputNormalizer.present_or_false?("0\n")).to eq true
      expect(Binxtils::InputNormalizer.present_or_false?(0)).to eq true
    end
    it "is false for blank" do
      expect(Binxtils::InputNormalizer.present_or_false?(nil)).to eq false
      expect(Binxtils::InputNormalizer.present_or_false?("")).to eq false
      expect(Binxtils::InputNormalizer.present_or_false?("   \n")).to eq false
    end
    it "is true for strings" do
      expect(Binxtils::InputNormalizer.present_or_false?("something")).to eq true
      expect(Binxtils::InputNormalizer.present_or_false?(true)).to eq true
      expect(Binxtils::InputNormalizer.present_or_false?(3)).to eq true
    end
  end

  describe "string" do
    it "returns nil for blank" do
      expect(Binxtils::InputNormalizer.string(nil)).to be_nil
      expect(Binxtils::InputNormalizer.string("")).to be_nil
      expect(Binxtils::InputNormalizer.string("   ")).to be_nil
    end
    it "strips and removes extra spaces" do
      expect(Binxtils::InputNormalizer.string(" D  ")).to eq "D"
      expect(Binxtils::InputNormalizer.string(" D HI \Z \nf ")).to eq "D HI \Z f"
    end
  end

  describe "regex_escape" do
    it "is nil for blank" do
      expect(Binxtils::InputNormalizer.string(" ")).to be_nil
    end
    it "replaces" do
      expect(Binxtils::InputNormalizer.regex_escape("(((..{?}")).to eq "........"
    end
  end

  describe "sanitize" do
    it "is empty string for nil" do
      expect(Binxtils::InputNormalizer.sanitize).to eq ""
      expect(Binxtils::InputNormalizer.sanitize(nil)).to eq ""
      expect(Binxtils::InputNormalizer.sanitize("\n\n")).to eq ""
    end
    it "is string for boolean" do
      expect(Binxtils::InputNormalizer.sanitize(true)).to eq "true"
      expect(Binxtils::InputNormalizer.sanitize(false)).to eq "false"
      expect(Binxtils::InputNormalizer.sanitize(" true")).to eq "true"
    end
    it "is strings for numbers" do
      expect(Binxtils::InputNormalizer.sanitize(5)).to eq "5"
      expect(Binxtils::InputNormalizer.sanitize(5_000)).to eq "5000"
      expect(Binxtils::InputNormalizer.sanitize(" 5000 ")).to eq "5000"
      expect(Binxtils::InputNormalizer.sanitize(5.000)).to eq "5.0"
      expect(Binxtils::InputNormalizer.sanitize(BigDecimal(0))).to eq "0.0"
    end
    it "doesn't remove text but does remove whitespace" do
      expect(Binxtils::InputNormalizer.sanitize("Some cool text ")).to eq "Some cool text"
      expect(Binxtils::InputNormalizer.sanitize(" Some \tcool \ntext")).to eq "Some cool text"
    end
    it "strips html tags" do
      expect(Binxtils::InputNormalizer.sanitize("<b>Hello</b> Plus other things</a>")).to eq "Hello Plus other things"
      expect(Binxtils::InputNormalizer.sanitize("<div><b>Hello</b> Plus other </div>things</a>")).to eq "Hello Plus other things"
    end
    it "strips out script" do
      expect(Binxtils::InputNormalizer.sanitize("<script>alert();</script>")).to eq ""
      expect(Binxtils::InputNormalizer.sanitize("<b>Hello</b><script>alert()</script>")).to eq "Hello"
      expect(Binxtils::InputNormalizer.sanitize('<b class="something">Hello</b><script>alert()</script>\\')).to eq "Hello\\"
    end
    it "returns bare ampersands" do
      expect(Binxtils::InputNormalizer.sanitize("Bike & Ski")).to eq "Bike & Ski"
      expect(Binxtils::InputNormalizer.sanitize("Bike &amp; Ski")).to eq "Bike & Ski"
    end
    it "leaves useful special characters" do
      expect(Binxtils::InputNormalizer.sanitize("Bike ())( /// Ski ")).to eq "Bike ())( /// Ski"
      expect(Binxtils::InputNormalizer.sanitize(' Bike [[] \\\ Ski ')).to eq 'Bike [[] \\\ Ski'
      expect(Binxtils::InputNormalizer.sanitize("Surly's Cross-check bike")).to eq "Surly's Cross-check bike"
    end
    it "leaves accents" do
      expect(Binxtils::InputNormalizer.sanitize("paké")).to eq "paké"
    end
    it "leaves emojis" do
      expect(Binxtils::InputNormalizer.sanitize("🧹")).to eq "🧹"
    end
    it "removes angle brackets" do
      expect(Binxtils::InputNormalizer.sanitize("Bike < Ski")).to eq "Bike &lt; Ski"
      expect(Binxtils::InputNormalizer.sanitize("Bike &lt; Ski")).to eq "Bike &lt; Ski"
      expect(Binxtils::InputNormalizer.sanitize("Bike > Ski")).to eq "Bike &gt; Ski"
      expect(Binxtils::InputNormalizer.sanitize("Bike &gt; Ski")).to eq "Bike &gt; Ski"
      expect(Binxtils::InputNormalizer.sanitize("Bike <> Ski")).to eq "Bike &lt;&gt; Ski"
      expect(Binxtils::InputNormalizer.sanitize("Bike &lt;&gt; Ski")).to eq "Bike &lt;&gt; Ski"
    end
  end
end
