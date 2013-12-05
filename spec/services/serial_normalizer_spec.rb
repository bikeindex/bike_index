require 'spec_helper'

describe SerialNormalizer do

  describe :normalize do 
    it "should upcase" do 
      serial = "happY"
      result = SerialNormalizer.new({serial: serial}).normalized
      result.should eq("HAPPY")
    end
    it "should normalize o and i" do 
      serial = "Ii0O0OiOOlli"
      result = SerialNormalizer.new({serial: serial}).normalized
      result.should eq("110000100111")
    end

    it "should normalize 5 2 z and b" do 
      serial = "bobs-catz"
      result = SerialNormalizer.new({serial: serial}).normalized
      result.should eq("8085-CAT2")
    end
  end

  describe :set_normalized do 
    it "should set a bike's normalized serial" do 
      bike = FactoryGirl.create(:bike, serial_number: "bobs-ill-catz")
      SerialNormalizer.new({bike_id: bike.id}).set_normalized
      bike.reload.serial_normalized.should eq("8085-111-CAT2")
    end
  end

end