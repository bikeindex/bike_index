require 'spec_helper'

describe WheelSize do
  describe :validations do 
    it { should validate_presence_of :name }
    it { should validate_presence_of :wheel_size_set }
    it { should validate_presence_of :description }
    it { should validate_presence_of :iso_bsd }
    it { should validate_uniqueness_of :name }  
    it { should validate_uniqueness_of :description }
    it { should validate_uniqueness_of :iso_bsd }
  end
end
