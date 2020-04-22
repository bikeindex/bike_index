require "rails_helper"

RSpec.describe Location, type: :model do
  it_behaves_like "geocodeable"

  describe "set_calculated_attributes" do
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

  describe "shown, not_publicly_visible" do
    let(:organization) { FactoryBot.create(:organization, shown_on_map: true, approved: false) }
    let(:location) { FactoryBot.create(:location, organization: organization) }
    it "sets based on organization and not_publicly_visible" do
      expect(organization.allowed_show?)
    end
  end

  describe "impound_location, default_impound_location, organization setting" do
    let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: ["impound_bikes"]) }
    it "sets the "
  end
end
