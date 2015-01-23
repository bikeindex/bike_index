require 'spec_helper'

describe CycleType do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :name }  
    it { should validate_presence_of :slug }
    it { should validate_uniqueness_of :slug }  
  end

  describe :slugs do 
    # This is to make it so that the API v2 doesn't break since we require bike, 
    # and make a list based on slugs and if slugs isn't there (as it isn't in most places in the tests),
    # it breaks.
    it "returns bike even if there are no slugs" do 
      CycleType.slugs.should eq(['bike'])
    end
    it "returns the slugs" do 
      FactoryGirl.create(:cycle_type)
      slugs = CycleType.slugs
      (slugs.any?).should be_true
      slugs.include?('bike').should be_false
    end
  end
end
