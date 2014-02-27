require 'spec_helper'

describe SerialNormalizer do

  describe :normalize do 
    it "should normalize i o 5 2 z and b" do 
      serial = "bobs-catzio"
      result = SerialNormalizer.new({serial: serial}).normalized
      result.should eq("8085 CAT210")
    end
    it "should normalize -_+= and multiple spaces" do 
      serial = "s>e-r--i+a_l"
      result = SerialNormalizer.new({serial: serial}).normalized
      result.should eq("5 E R 1 A 1")
    end
  end

end