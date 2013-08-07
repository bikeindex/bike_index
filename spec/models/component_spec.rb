require 'spec_helper'

describe Component do

  describe :validations do
    it { should belong_to :bike }
    it { should belong_to :manufacturer }
    it { should belong_to :ctype }
    it { should validate_presence_of :ctype_id }
  end

  describe :component_type do 
    it "should return the name of the ctype other if it should" do 
      ctype = Ctype.new
      component = Component.new
      component.stub(:ctype).and_return(ctype)
      ctype.stub(:name).and_return("Other")
      component.stub(:ctype_other).and_return("OOOP")
      component.component_type.should eq("OOOP")
    end

    it "should return the name of the ctype" do 
      ctype = Ctype.new
      component = Component.new
      component.stub(:ctype).and_return(ctype)
      ctype.stub(:name).and_return("stuff")
      component.component_type.should eq("stuff")
    end
  end

  describe :manufacturer_name do 
    it "should return the value of manufacturer_other if manufacturer is other" do 
      mnfg = Ctype.new
      component = Component.new
      component.stub(:manufacturer).and_return(mnfg)
      mnfg.stub(:name).and_return("stuff")
      component.manufacturer_name.should eq("stuff")
    end

    it "should return the name of the manufacturer if it isn't other" do
      mnfg = Ctype.new
      component = Component.new
      component.stub(:manufacturer).and_return(mnfg)
      component.stub(:manufacturer_other).and_return("oooop")
      mnfg.stub(:name).and_return("Other")
      component.manufacturer_name.should eq("oooop")
    end
  end

end
