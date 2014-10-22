require 'spec_helper'

describe Location do 
  describe :validations do
    it { should belong_to :organization }
    it { should belong_to :country }
    it { should belong_to :state }
    it { should have_many :bikes }
    it { should validate_presence_of :name }
    it { should validate_presence_of :organization_id }
    it { should validate_presence_of :city }
    it { should validate_presence_of :country_id }
  end

  
  describe :set_phone do
    it "strips the non-digit numbers from the phone input" do
      location = FactoryGirl.create(:location, phone: '773.83ddp+83(887)')
      location.phone.should eq('7738383887')
    end
  end

  describe :address do 
    it "strips the non-digit numbers from the phone input" do
      location = FactoryGirl.create(:location)
      location.address.should be_a(String)
    end
    it "creates an address" do 
      c = Country.create(name: "Neverland", iso: "XXX")
      s = State.create(country_id: c.id, name: "BullShit", abbreviation: "XXX")
      location = FactoryGirl.create(:location, street: "300 Blossom Hill Dr", city: "Lancaster", state_id: s.id, zipcode: "17601", country_id: c.id)
      location.address.should eq("300 Blossom Hill Dr, Lancaster, XXX, 17601, Neverland")
    end
  end

  describe :org_location_id do 
    it "creates a unique id that references the organization" do 
      location = FactoryGirl.create(:location)
      location.org_location_id.should eq("#{location.organization_id}_#{location.id}")
    end
  end

end
