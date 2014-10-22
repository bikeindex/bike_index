require 'spec_helper'

describe Country do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :iso }
    it { should validate_uniqueness_of :iso }
    it { should have_many :stolen_records }
    it { should have_many :locations }
  end


  describe :fuzzy_iso_find do
    it "finds the country by ISO address when the case doesn't match" do
      country = Country.create(name: "EEEEEEEh", iso: "LULZ" )
      Country.fuzzy_iso_find('lulz ').should == country
    end
    it "finds USA" do
      country = Country.create(name: "United States", iso: "US" )
      Country.fuzzy_iso_find('USA').should == country
    end
  end
end
