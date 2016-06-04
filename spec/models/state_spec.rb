require 'spec_helper'

describe State do
  describe 'validations' do
    it { is_expected.to have_many :locations }
    it { is_expected.to have_many :stolen_records }
    it { is_expected.to belong_to :country }
    it { is_expected.to validate_presence_of :country_id }
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to validate_presence_of :abbreviation }
    it { is_expected.to validate_uniqueness_of :name }
    it { is_expected.to validate_uniqueness_of :abbreviation }
  end

  describe 'fuzzy_abbr_find' do
    it "finds users by email address when the case doesn't match" do
      state = FactoryGirl.create(:state, abbreviation: 'LULZ')
      expect(State.fuzzy_abbr_find('lulz ')).to eq(state)
    end
  end
end
