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

  describe "regex_escape" do
    it "is nil for blank" do
      expect(InputNormalizer.string(" ")).to be_nil
    end
    it "replaces" do
      expect(InputNormalizer.regex_escape("(((..{?}")).to eq "........"
    end
  end

  describe "sanitize" do
    it "is empty string for nil" do
      expect(InputNormalizer.sanitize).to eq ""
      expect(InputNormalizer.sanitize(nil)).to eq ""
      expect(InputNormalizer.sanitize("\n\n")).to eq ""
    end
    it "is string for boolean" do
      expect(InputNormalizer.sanitize(true)).to eq "true"
      expect(InputNormalizer.sanitize(false)).to eq "false"
      expect(InputNormalizer.sanitize(" true")).to eq "true"
    end
    it "is strings for numbers" do
      expect(InputNormalizer.sanitize(5)).to eq "5"
      expect(InputNormalizer.sanitize(5_000)).to eq "5000"
      expect(InputNormalizer.sanitize(" 5000 ")).to eq "5000"
      expect(InputNormalizer.sanitize(5.000)).to eq "5.0"
      expect(InputNormalizer.sanitize(BigDecimal(0))).to eq "0.0"
    end
    it "doesn't remove text but does remove whitespace" do
      expect(InputNormalizer.sanitize("Some cool text ")).to eq "Some cool text"
      expect(InputNormalizer.sanitize(" Some \tcool \ntext")).to eq "Some cool text"
    end
    it "strips html tags" do
      expect(InputNormalizer.sanitize("<b>Hello</b> Plus other things</a>")).to eq "Hello Plus other things"
      expect(InputNormalizer.sanitize("<div><b>Hello</b> Plus other </div>things</a>")).to eq "Hello Plus other things"
    end
    it "strips out script" do
      expect(InputNormalizer.sanitize("<script>alert();</script>")).to eq ""
      expect(InputNormalizer.sanitize("<b>Hello</b><script>alert()</script>")).to eq "Hello"
      expect(InputNormalizer.sanitize('<b class="something">Hello</b><script>alert()</script>\\')).to eq "Hello\\"
    end
    it "returns bare ampersands" do
      expect(InputNormalizer.sanitize("Bike & Ski")).to eq "Bike & Ski"
      expect(InputNormalizer.sanitize("Bike &amp; Ski")).to eq "Bike & Ski"
    end
    it "leaves useful special characters" do
      expect(InputNormalizer.sanitize("Bike ())( /// Ski ")).to eq "Bike ())( /// Ski"
      expect(InputNormalizer.sanitize(' Bike [[] \\\ Ski ')).to eq 'Bike [[] \\\ Ski'
      expect(InputNormalizer.sanitize("Surly's Cross-check bike")).to eq "Surly's Cross-check bike"
    end
    it "leaves accents" do
      expect(InputNormalizer.sanitize("paké")).to eq "paké"
    end
    it "leaves emojis" do
      expect(InputNormalizer.sanitize("🧹")).to eq "🧹"
    end
    it "removes angle brackets" do
      expect(InputNormalizer.sanitize("Bike < Ski")).to eq "Bike &lt; Ski"
      expect(InputNormalizer.sanitize("Bike &lt; Ski")).to eq "Bike &lt; Ski"
      expect(InputNormalizer.sanitize("Bike > Ski")).to eq "Bike &gt; Ski"
      expect(InputNormalizer.sanitize("Bike &gt; Ski")).to eq "Bike &gt; Ski"
      expect(InputNormalizer.sanitize("Bike <> Ski")).to eq "Bike &lt;&gt; Ski"
      expect(InputNormalizer.sanitize("Bike &lt;&gt; Ski")).to eq "Bike &lt;&gt; Ski"
    end
  end
end
