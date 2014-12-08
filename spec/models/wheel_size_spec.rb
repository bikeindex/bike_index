require 'spec_helper'

describe WheelSize do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_presence_of :priority }
    it { should validate_presence_of :description }
    it { should validate_presence_of :iso_bsd }
    it { should validate_uniqueness_of :description }
    it { should validate_uniqueness_of :iso_bsd }
  end

  describe :popularity do 
    it "returns the popularities word of the wheel size" do
      wheel_size = WheelSize.new(priority: 1)
      wheel_size.popularity.should eq("Standard")
      wheel_size.priority = 4
      wheel_size.popularity.should eq("Rare")
    end
  end
end
