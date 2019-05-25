require "spec_helper"

describe State do
  describe "fuzzy_abbr_find" do
    it "finds users by email address when the case doesn't match" do
      state = FactoryBot.create(:state, abbreviation: "LULZ")
      expect(State.fuzzy_abbr_find("lulz ")).to eq(state)
    end
  end
end
