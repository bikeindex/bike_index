require 'spec_helper'

describe LockType do
  describe :validations do
    before do
      @lock_type = LockType.create(name: "something")
    end
    it { should validate_presence_of :name }
    it { should validate_uniqueness_of :name }
    it { should validate_uniqueness_of :slug }
  end
  
  describe :manufacturer_name do 
    it "returns the value of manufacturer_other if manufacturer is other" do 
      lock = Lock.new
      other_manufacturer = Manufacturer.new 
      other_manufacturer.stub(:name).and_return("Other")
      lock.stub(:manufacturer).and_return(other_manufacturer)
      lock.stub(:manufacturer_other).and_return("Other manufacturer name")
      lock.manufacturer_name.should eq("Other manufacturer name")
    end

    it "returns the name of the manufacturer if it isn't other" do
      lock = Lock.new
      manufacturer = Manufacturer.new 
      manufacturer.stub(:name).and_return("Mnfg name")
      lock.stub(:manufacturer).and_return(manufacturer)
      lock.manufacturer_name.should eq("Mnfg name")
    end
  end
end
