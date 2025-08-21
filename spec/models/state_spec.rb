# == Schema Information
#
# Table name: states
#
#  id           :integer          not null, primary key
#  abbreviation :string(255)
#  name         :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  country_id   :integer
#
# Indexes
#
#  index_states_on_country_id  (country_id)
#
require "rails_helper"

RSpec.describe State, type: :model do
  describe "factory" do
    let(:state) { FactoryBot.create(:state_illinois) }
    it "is valid and only creates once" do
      expect(state).to be_valid
      expect(FactoryBot.create(:state_illinois).id).to eq state.id
      expect(state.country_id).to eq Country.united_states_id
      expect(State.united_states.pluck(:id)).to eq([state.id])
    end
    context "in canada" do
      let(:state) { FactoryBot.create(:state_alberta) }
      it "is valid and only creates once" do
        expect(state).to be_valid
        expect(FactoryBot.create(:state_alberta).id).to eq state.id
        expect(state.country_id).to_not eq Country.united_states_id
        expect(State.united_states.pluck(:id)).to eq([])
      end
    end
  end

  describe "fuzzy_abbr_find" do
    it "finds users by email address when the case doesn't match" do
      state = FactoryBot.create(:state, abbreviation: "LULZ")
      expect(State.fuzzy_abbr_find("lulz ")).to eq(state)
    end
  end
end
