require 'spec_helper'

describe Color do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_presence_of :priority }
    it { should validate_uniqueness_of :name }
  end

  describe :fuzzy_name_find do
    it "should find users by email address when the case doesn't match" do
      color = FactoryGirl.create(:color, name: "Poopy PANTERS")
      Color.fuzzy_name_find('poopy panters').should == color
    end
  end
end
