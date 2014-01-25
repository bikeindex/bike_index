require 'spec_helper'

describe SerialNormalizer do

  describe :normalize do 
    it "should normalize i o 5 2 z and b" do 
      serial = "bobs-catzio"
      result = SerialNormalizer.new({serial: serial}).normalized
      result.should eq("8085-CAT210")
    end
  end

  describe :set_normalized do 
    it "should set a bike's normalized serial" do 
      bike = FactoryGirl.create(:bike, serial_number: "bobs-ill-catz")
      SerialNormalizer.new({bike_id: bike.id}).set_normalized
      bike.reload.serial_normalized.should eq("8085-111-CAT2")
    end
    it "should return absent if a serial is absent" do 
      bike = FactoryGirl.create(:bike, serial_number: "absent")
      SerialNormalizer.new({bike_id: bike.id}).set_normalized
      bike.reload.serial_normalized.should eq("absent")
    end
  end

  describe :search do
    it "should search for normalized serials" do
      normalizer = SerialNormalizer.new(serial: "Boots")
      normalizer.should_receive(:normalized).and_return("b00t5")
      normalizer.should_receive(:find_normalized).and_return(true)
      normalizer.search 
    end
  end

  describe :find_normalized do 
    xit "should find normalized" do 
      # Not sure how to test this...
    end
  end

end