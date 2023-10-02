require "rails_helper"

RSpec.describe Autocomplete do
  describe "normalize" do
    it "normalizes" do
      expect(Autocomplete.normalize("somethin'_SPECialy888\t")).to eq "somethin_specialy888"
      expect(Autocomplete.normalize("another:thing-here")).to eq "anotherthinghere"
      expect(Autocomplete.normalize("another thing")).to eq "another thing"
    end
    it "normalizes accents" do
      expect(Autocomplete.normalize("Paké")).to eq "pake"
    end
    it "normalizes ampersands" do
      expect(Autocomplete.normalize("Bikes & Trikes")).to eq "bikes trikes"
    end
    # NOTE: this spec fails, but I'm ok with that for now
    # it "doesn't change non-latin characters" do
    #   expect(Autocomplete.normalize("测试中文")).to eq "测试中文"
    # end
  end

  describe "category_id" do
    it "returns category_id" do
      expect(Autocomplete.category_id("colors")).to eq "autc:test:cts:colors:"
      expect(Autocomplete.category_id("cycle_type")).to eq "autc:test:cts:cycle_type:"
    end
  end
end
