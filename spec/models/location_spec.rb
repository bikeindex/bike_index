require "rails_helper"

RSpec.describe Location, type: :model do
  describe "set_phone" do
    it "strips the non-digit numbers from the phone input" do
      location = FactoryBot.create(:location, phone: "773.83ddp+83(887)")
      expect(location.phone).to eq("7738383887")
    end
  end

  describe "address" do
    it "strips the non-digit numbers from the phone input" do
      location = FactoryBot.create(:location)
      expect(location.address).to be_a(String)
    end
    it "creates an address, ignoring blank fields" do
      c = Country.create(name: "Neverland", iso: "XXX")
      s = State.create(country_id: c.id, name: "BullShit", abbreviation: "XXX")

      location = Location.create(street: "300 Blossom Hill Dr", city: "Lancaster", state_id: s.id, zipcode: "17601", country_id: c.id)
      expect(location.address).to eq("300 Blossom Hill Dr, Lancaster, XXX, 17601, Neverland")

      location.update(street: " ")
      expect(location.address).to eq("Lancaster, XXX, 17601, Neverland")
    end
  end

  describe "org_location_id" do
    it "creates a unique id that references the organization" do
      location = FactoryBot.create(:location)
      expect(location.org_location_id).to eq("#{location.organization_id}_#{location.id}")
    end
  end
end
