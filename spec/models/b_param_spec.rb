require 'spec_helper'

describe BParam do
  describe :validations do
    it { should belong_to :created_bike }
    it { should belong_to :creator }
    it { should validate_presence_of :creator }
  end

  describe :bike do 
    it "should return the bike attribs" do 
      b_param = BParam.new 
      b_param.stub(:params).and_return({:bike => {serial_number: "XXX"}})
      b_param.bike[:serial_number].should eq("XXX")
    end
  end

end
