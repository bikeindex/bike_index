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

  describe :normalized_segments do 
    it "should make normalized segments" do 
      segments = SerialNormalizer.new({serial: "some + : serial"}).normalized_segments
      segments.count.should eq(2)
      segments[0].should eq('50ME')
    end
    it "should return nil if serial is absent" do
      segments = SerialNormalizer.new({serial: "absent"}).normalized_segments
      segments.should be_nil
    end
  end

  describe :save_segments do 
    it "should save normalized segments with the bike_id and not break if we resave" do 
      bike = FactoryGirl.create(:bike)
      SerialNormalizer.new({serial: "some + : serial"}).save_segments(bike.id)
      NormalizedSerialSegment.where(bike_id: bike.id).count.should eq(2)
    end

    it "shouldn't save absent segments" do 
      bike = FactoryGirl.create(:bike)
      SerialNormalizer.new({serial: "absent"}).save_segments(bike.id)
      NormalizedSerialSegment.where(bike_id: bike.id).count.should eq(0)
    end

    it "should rewrite the segments if we save them a second time" do 
      bike = FactoryGirl.create(:bike)
      SerialNormalizer.new({serial: "some + : serial"}).save_segments(bike.id)
      NormalizedSerialSegment.where(bike_id: bike.id).count.should eq(2)
      SerialNormalizer.new({serial: "another + : THING"}).save_segments(bike.id)
      segments = NormalizedSerialSegment.where(bike_id: bike.id)
      segments.count.should eq(2)
      segments[0].segment.should eq('AN0THER')
    end

    it "shouldn't make any if the bike is an example bike" do 
      bike = FactoryGirl.create(:bike)
      bike.update_attributes(example: true)
      SerialNormalizer.new({serial: "some + : serial"}).save_segments(bike.id)
      NormalizedSerialSegment.where(bike_id: bike.id).count.should eq(0)
    end

  end



end