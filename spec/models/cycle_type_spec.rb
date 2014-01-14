require 'spec_helper'

describe CycleType do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :name }  
  end

  describe :fuzzy_name_find do
    it "should find users by email address when the case doesn't match" do
      ct = FactoryGirl.create(:cycle_type, name: "TRY Unicycle")
      CycleType.fuzzy_name_find(' try uNicycle  ').should == ct
    end
  end

end
