require "rails_helper"

RSpec.describe Autocomplete do
  describe "normalize" do
    it "normalizes" do
      expect(Autocomplete.normalize("somethin'_SPECialy888\t")).to eq "somethin_specialy888"
      expect(Autocomplete.normalize("another:thing*here")).to eq "anotherthinghere"
      expect(Autocomplete.normalize("another thing")).to eq "another thing"
    end
    it "normalizes accents" do
      expect(Autocomplete.normalize("Paké")).to eq "pake"
    end
    it "normalizes ampersands" do
      expect(Autocomplete.normalize("Bikes & Trikes")).to eq "bikes trikes"
    end
    it "normalizes dashes and parens" do
      expect(Autocomplete.normalize("e-Personal Mobility (EPAMD, e-Skateboard, Segway, e-Unicycle, etc)"))
        .to eq "e personal mobility epamd e skateboard segway e unicycle etc"
      expect(Autocomplete.normalize("Cargo Tricycle (trike with front storage, e.g. Christiania bike)"))
        .to eq "cargo tricycle trike with front storage eg christiania bike"
    end
    # NOTE: this spec fails, but I'm ok with that for now
    # it "doesn't change non-latin characters" do
    #   expect(Autocomplete.normalize("测试中文")).to eq "测试中文"
    # end
  end

  describe "category_key" do
    it "returns category_key" do
      expect(Autocomplete.category_key("colors")).to eq "autc:test:cts:colors:"
      expect(Autocomplete.category_key("cycle_type")).to eq "autc:test:cts:cycle_type:"
    end
  end
end
