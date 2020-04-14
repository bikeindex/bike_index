require "rails_helper"

RSpec.describe Location, type: :model do
  describe "set_phone" do
    it "strips the non-digit numbers from the phone input" do
      location = FactoryBot.create(:location, phone: "773.83ddp+83(887)")
      expect(location.phone).to eq("7738383887")
    end
  end

  describe "address" do
    it "creates an address, ignoring blank fields" do
      c = Country.create(name: "Neverland", iso: "NEV")
      s = State.create(country_id: c.id, name: "BullShit", abbreviation: "BS")

      location = Location.create(street: "300 Blossom Hill Dr", city: "Lancaster", state_id: s.id, zipcode: "17601", country_id: c.id)
      expect(location.address).to eq("300 Blossom Hill Dr, Lancaster, BS 17601, Neverland")

      location.update(street: " ")
      expect(location.address).to eq("Lancaster, BS 17601, Neverland")
    end
  end

  describe "org_location_id" do
    it "creates a unique id that references the organization" do
      location = FactoryBot.create(:location)
      expect(location.org_location_id).to eq("#{location.organization_id}_#{location.id}")
    end
  end

  describe "assigning state and country" do
    let(:country) { Country.united_states }
    let!(:state) { State.create(name: "Wyoming", abbreviation: "WY", country_id: country.id) }
    let(:location_with_strings) { Location.new(state: "wy", country: "USA") }
    let(:location_with_objects) { Location.new(state: state, country_id: country.id) }
    it "assigns by strings and by object, doesn't explode when not found" do
      expect(location_with_strings.country).to eq country
      expect(location_with_strings.state).to eq state
      location_with_strings.state = "wyoming"
      expect(location_with_strings.state).to eq state

      expect(location_with_objects.country).to eq country
      expect(location_with_objects.state).to eq state
      # Doesn't explode when not found
      location_with_objects.state = "Other state"
      expect(location_with_objects.state).to be_blank
    end
  end
end
