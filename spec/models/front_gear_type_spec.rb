require 'spec_helper'

describe FrontGearType do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_presence_of :count }
    it { should validate_uniqueness_of :name } 
  end
end
