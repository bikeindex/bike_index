require 'spec_helper'

describe State do
  describe :validations do
    it { should have_many :locations }
    it { should have_many :stolen_records }
    it { should belong_to :country }
    it { should validate_presence_of :country_id }
    it { should validate_presence_of :name }
    it { should validate_presence_of :abbreviation }
    it { should validate_uniqueness_of :name }
    it { should validate_uniqueness_of :abbreviation }
  end

  describe :fuzzy_abbr_find do
    it "finds users by email address when the case doesn't match" do
      state = FactoryGirl.create(:state, abbreviation: "LULZ" )
      State.fuzzy_abbr_find('lulz ').should == state
    end
  end
end
