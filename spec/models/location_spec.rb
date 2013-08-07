require 'spec_helper'

describe Location do 
  
  describe :set_phone do
    it "should strip the non-digit numbers from the phone input" do
      location = FactoryGirl.create(:location, phone: '773.83ddp+83(887)')
      location.phone.should eq('7738383887')
    end
  end

  describe :address do 
    it "should strip the non-digit numbers from the phone input" do
      location = FactoryGirl.create(:location)
      location.address.should be_a(String)
    end
  end

end
