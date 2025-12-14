require "rails_helper"

RSpec.describe Binxtils::InputNormalizer do
  let(:subject) { described_class }
  describe "boolean" do
    context "1" do
      it "returns true" do
        expect(subject.boolean(1)).to eq true
        expect(subject.boolean(" 1")).to eq true
      end
    end
    context "string" do
      it "returns true" do
        expect(subject.boolean("something")).to eq true
        expect(subject.boolean(" Other Stuffff")).to eq true
      end
    end
    context "true" do
      it "returns true" do
        expect(subject.boolean(true)).to eq true
        expect(subject.boolean("true ")).to eq true
      end
    end
    context "nil" do
      it "returns false" do
        expect(subject.boolean).to eq false
        expect(subject.boolean(nil)).to eq false
      end
    end
    context "false" do
      it "returns false" do
        expect(subject.boolean(false)).to eq false
        expect(subject.boolean("false\n")).to eq false
      end
    end
  end

  describe "present_or_false?" do
    it "is true for false values" do
      expect(false.present?).to be_falsey # This is the problem!
      expect(subject.present_or_false?(false)).to eq true
      expect(subject.present_or_false?("false\n")).to eq true
      expect(subject.present_or_false?("0\n")).to eq true
      expect(subject.present_or_false?(0)).to eq true
    end
    it "is false for blank" do
      expect(subject.present_or_false?(nil)).to eq false
      expect(subject.present_or_false?("")).to eq false
      expect(subject.present_or_false?("   \n")).to eq false
    end
    it "is true for strings" do
      expect(subject.present_or_false?("something")).to eq true
      expect(subject.present_or_false?(true)).to eq true
      expect(subject.present_or_false?(3)).to eq true
    end
  end

  describe "string" do
    it "returns nil for blank" do
      expect(subject.string(nil)).to be_nil
      expect(subject.string("")).to be_nil
      expect(subject.string("   ")).to be_nil
    end
    it "strips and removes extra spaces" do
      expect(subject.string(" D  ")).to eq "D"
      expect(subject.string(" D HI \Z \nf ")).to eq "D HI \Z f"
    end
  end

  describe "regex_escape" do
    it "is nil for blank" do
      expect(subject.string(" ")).to be_nil
    end
    it "replaces" do
      expect(subject.regex_escape("(((..{?}")).to eq "........"
    end
  end

  describe "sanitize" do
    it "is empty string for nil" do
      expect(subject.sanitize).to eq ""
      expect(subject.sanitize(nil)).to eq ""
      expect(subject.sanitize("\n\n")).to eq ""
    end
    it "is string for boolean" do
      expect(subject.sanitize(true)).to eq "true"
      expect(subject.sanitize(false)).to eq "false"
      expect(subject.sanitize(" true")).to eq "true"
    end
    it "is strings for numbers" do
      expect(subject.sanitize(5)).to eq "5"
      expect(subject.sanitize(5_000)).to eq "5000"
      expect(subject.sanitize(" 5000 ")).to eq "5000"
      expect(subject.sanitize(5.000)).to eq "5.0"
      expect(subject.sanitize(BigDecimal(0))).to eq "0.0"
    end
    it "doesn't remove text but does remove whitespace" do
      expect(subject.sanitize("Some cool text ")).to eq "Some cool text"
      expect(subject.sanitize(" Some \tcool \ntext")).to eq "Some cool text"
    end
    it "strips html tags" do
      expect(subject.sanitize("<b>Hello</b> Plus other things</a>")).to eq "Hello Plus other things"
      expect(subject.sanitize("<div><b>Hello</b> Plus other </div>things</a>")).to eq "Hello Plus other things"
    end
    it "strips out script" do
      expect(subject.sanitize("<script>alert();</script>")).to eq ""
      expect(subject.sanitize("<b>Hello</b><script>alert()</script>")).to eq "Hello"
      expect(subject.sanitize('<b class="something">Hello</b><script>alert()</script>\\')).to eq "Hello\\"
    end
    it "returns bare ampersands" do
      expect(subject.sanitize("Bike & Ski")).to eq "Bike & Ski"
      expect(subject.sanitize("Bike &amp; Ski")).to eq "Bike & Ski"
    end
    it "leaves useful special characters" do
      expect(subject.sanitize("Bike ())( /// Ski ")).to eq "Bike ())( /// Ski"
      expect(subject.sanitize(' Bike [[] \\\ Ski ')).to eq 'Bike [[] \\\ Ski'
      expect(subject.sanitize("Surly's Cross-check bike")).to eq "Surly's Cross-check bike"
    end
    it "leaves accents" do
      expect(subject.sanitize("paké")).to eq "paké"
    end
    it "leaves emojis" do
      expect(subject.sanitize("🧹")).to eq "🧹"
    end
    it "removes angle brackets" do
      expect(subject.sanitize("Bike < Ski")).to eq "Bike &lt; Ski"
      expect(subject.sanitize("Bike &lt; Ski")).to eq "Bike &lt; Ski"
      expect(subject.sanitize("Bike > Ski")).to eq "Bike &gt; Ski"
      expect(subject.sanitize("Bike &gt; Ski")).to eq "Bike &gt; Ski"
      expect(subject.sanitize("Bike <> Ski")).to eq "Bike &lt;&gt; Ski"
      expect(subject.sanitize("Bike &lt;&gt; Ski")).to eq "Bike &lt;&gt; Ski"
    end
  end
end
