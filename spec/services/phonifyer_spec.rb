require "rails_helper"

RSpec.describe Phonifyer do
  describe "phonify" do
    context "blank" do
      it "returns nil" do
        expect(Phonifyer.phonify(nil)).to be_nil
        expect(Phonifyer.phonify(" ")).to be_nil
      end
    end
    context "no country code" do
      it "strips and remove non digits" do
        expect(Phonifyer.strip_ignored_parts("(999) 899 - 999")).to eq "999899999"
        expect(Phonifyer.split_with_country_code("(999) 899 - 999")).to eq(["(999) 899 - 999"])
        expect(Phonifyer.split_with_extension("(999) 899 - 999")).to eq(["(999) 899 - 999"])
        expect(Phonifyer.phonify("(999) 899 - 999")).to eq("999899999")
        # Also, just in case, test with an integer
        expect(Phonifyer.phonify(999899999)).to eq("999899999")
      end
    end

    describe "country_code parsing" do
      it "does not remove the 1" do
        expect(Phonifyer.split_with_country_code("+1 80 4150 5583")).to eq(["80 4150 5583", "+1"])
        expect(Phonifyer.split_with_country_code("+18041505583")).to eq(["8041505583", "+1"])
        expect(Phonifyer.split_with_country_code("+1 8041505583")).to eq(["8041505583", "+1"])
        # And test the whole phonify works
        expect(Phonifyer.phonify(" +1 80 4150 5583")).to eq("+1 8041505583")
        expect(Phonifyer.phonify("+18041505583")).to eq("+1 8041505583")
        expect(Phonifyer.phonify("+1 8041505583")).to eq("+1 8041505583")
      end
      it "does not remove the 881" do
        expect(Phonifyer.split_with_country_code("+881 80 4150 5583")).to eq(["80 4150 5583", "+881"])
        expect(Phonifyer.split_with_country_code("+8818041505583")).to eq(["8041505583", "+881"])
        # And test the whole phonify works
        expect(Phonifyer.phonify("\t+881 80 4150 5583")).to eq("+881 8041505583")
        expect(Phonifyer.phonify("+8818041505583")).to eq("+881 8041505583")
      end
      it "does not remove the 91" do
        expect(Phonifyer.split_with_country_code("+91 80 4150 5583")).to eq(["80 4150 5583", "+91"])
        expect(Phonifyer.split_with_country_code("+918041505583")).to eq(["8041505583", "+91"])
        # And test the whole phonify works
        expect(Phonifyer.phonify("+91 80 4150 5583")).to eq("+91 8041505583")
        expect(Phonifyer.phonify("+918041505583")).to eq("+91 8041505583")
      end
      it "does not remove 35" do
        expect(Phonifyer.split_with_country_code("+35-3871730000")).to eq(["-3871730000", "+35"])
        expect(Phonifyer.split_with_country_code("+35(387)173-0000")).to eq(["(387)173-0000", "+35"])
        expect(Phonifyer.split_with_country_code("+35 3871730000")).to eq(["3871730000", "+35"])
        # And test the whole phonify works
        expect(Phonifyer.phonify("+35-3871730000")).to eq "+35 3871730000"
        expect(Phonifyer.phonify("+35(387)173-0000")).to eq "+35 3871730000"
        expect(Phonifyer.phonify("+35 3871730000")).to eq "+35 3871730000"
      end
      it "does not remove 44" do
        expect(Phonifyer.split_with_country_code("+44 780 273 0000")).to eq(["780 273 0000", "+44"])
        expect(Phonifyer.split_with_country_code("+44 (780) 273-0000")).to eq(["(780) 273-0000", "+44"])
        expect(Phonifyer.split_with_country_code("+447802730000 ext.121222")).to eq(["7802730000 ext.121222", "+44"])
        # And test the whole phonify works
        expect(Phonifyer.phonify("+44 780 273 0000")).to eq "+44 7802730000"
        expect(Phonifyer.phonify("+447802730000 ext.121222")).to eq "+44 7802730000 x121222"
      end
    end

    context "with extension" do
      it "includes x" do
        expect(Phonifyer.split_with_extension("800.478.2111 x1111")).to eq(["800.478.2111", "x1111"])
        expect(Phonifyer.split_with_extension("800.478.2111x1111")).to eq(["800.478.2111", "x1111"])
        expect(Phonifyer.split_with_extension("8004782111 ext 1111")).to eq(["8004782111", "x1111"])
        expect(Phonifyer.split_with_extension("(800)478-2111 ext. 1111")).to eq(["(800)478-2111", "x1111"])
        expect(Phonifyer.split_with_extension("8004782111 EXT.1111")).to eq(["8004782111", "x1111"])
        expect(Phonifyer.split_with_extension("800478.2111 extension 1111")).to eq(["800478.2111", "x1111"])
        # And test the whole phonify works
        expect(Phonifyer.phonify("800.478.2111 x1111")).to eq "8004782111 x1111"
        expect(Phonifyer.phonify("8004782111 ext 1111")).to eq "8004782111 x1111"
        expect(Phonifyer.phonify("(800)478-2111 ext. 1111")).to eq "8004782111 x1111"
        expect(Phonifyer.phonify("8004782111 EXT.1111")).to eq "8004782111 x1111"
        expect(Phonifyer.phonify("800478.2111 extension: 1111")).to eq "8004782111 x1111"
        # With just a BS number it doesn't crash
        expect(Phonifyer.phonify("xxxxxxxxxx")).to be_blank
      end
    end

    context "extra stuff" do
      it "doesn't remove it" do
        expect(Phonifyer.phonify("19865352717,,984989999#")).to eq("19865352717,,984989999#")
        expect(Phonifyer.phonify("+19865352717,;984989999#")).to eq("+1 9865352717,;984989999#")
        expect(Phonifyer.phonify("+19865352717 ,; 984989999#")).to eq("+1 9865352717,;984989999#")
        expect(Phonifyer.phonify("+8819865352717,,984989999#")).to eq("+881 9865352717,,984989999#")
      end
    end
  end

  describe "components" do
    it "separates into components" do
      expect(Phonifyer.components("8004782111")).to eq({number: "8004782111"})
      expect(Phonifyer.components("8004782111 x1111")).to eq({number: "8004782111", extension: "1111"})
      expect(Phonifyer.components("+1 8004782111 x1111")).to eq({country_code: "1", number: "8004782111", extension: "1111"})
      expect(Phonifyer.components("+19865352717,;984989999#")).to eq({country_code: "1", number: "9865352717,;984989999#"})
      expect(Phonifyer.components("+447802730000 ext.121222")).to eq({country_code: "44", number: "7802730000", extension: "121222"})
    end
    it "does 7 digit numbers" do
      expect(Phonifyer.components("0000000")).to eq({number: "0000000"})
      expect(Phonifyer.components("0000000 x89999")).to eq({number: "0000000", extension: "89999"})
    end
  end
end
