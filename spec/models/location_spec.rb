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

  describe :org_location_id do 
    it "should create a unique id that references the organization" do 
      location = FactoryGirl.create(:location)
      location.org_location_id.should eq("#{location.organization_id}_#{location.id}")
    end
  end

end
