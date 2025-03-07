require "rails_helper"

RSpec.describe Location, type: :model do
  it_behaves_like "geocodeable"

  describe "set_calculated_attributes" do
    it "strips the non-digit numbers from the phone input" do
      location = FactoryBot.create(:location, phone: "773.83ddp+83(887)")
      expect(location.phone).to eq("77383ddp+83887")
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

  describe "no name" do
    let(:organization) { FactoryBot.create(:organization) }
    it "uses the org name" do
      location = FactoryBot.build(:location, name: nil, organization: organization)
      expect(location.name).to be_blank
      location.save
      expect(location).to be_valid
      expect(location.name).to eq organization.name
    end
    context "with multiple locations" do
      let!(:location_pre) { FactoryBot.create(:location, organization: organization) }
      it "is invalid" do
        location = FactoryBot.build(:location, name: nil, organization: organization)
        expect(location.name).to be_blank
        location.save
        expect(location).to_not be_valid
      end
    end
  end

  describe "shown, not_publicly_visible" do
    let(:organization) { FactoryBot.create(:organization, show_on_map: true, approved: false) }
    let(:location) { FactoryBot.create(:location, organization: organization) }
    it "sets based on organization and not_publicly_visible" do
      expect(organization.allowed_show?).to be_falsey
      expect(location.shown).to be_falsey
      expect(location.not_publicly_visible).to be_falsey
      expect(location.destroy_forbidden?).to be_falsey
      organization.reload
      Sidekiq::Job.clear_all
      expect {
        organization.update(approved: true, skip_update: false)
      }.to change(UpdateOrganizationAssociationsJob.jobs, :count).by 1
      UpdateOrganizationAssociationsJob.drain
      location.reload
      expect(location.shown).to be_truthy
      location.update(publicly_visible: false)
      expect(location.shown).to be_falsey
    end
  end

  describe "impound_location, default_impound_location, organization setting" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["impound_bikes"]) }
    let!(:location) { FactoryBot.create(:location, organization: organization) }
    let!(:location2) { FactoryBot.create(:location, organization: organization) }
    let(:impound_record) { FactoryBot.create(:impound_record_with_organization, location: location, organization: organization) }
    it "sets the impound_bikes_locations on organization setting" do
      expect(organization.default_impound_location).to be_blank
      expect(organization.enabled_feature_slugs).to eq(["impound_bikes"])
      Sidekiq::Job.clear_all
      expect {
        location.update(impound_location: true)
      }.to change(UpdateOrganizationAssociationsJob.jobs, :count).by 1
      UpdateOrganizationAssociationsJob.drain
      location.reload
      expect(location.default_impound_location).to be_truthy
      organization.reload
      expect(organization.default_impound_location).to eq location
      expect(organization.enabled_feature_slugs).to eq(%w[impound_bikes impound_bikes_locations])
      location2.update(impound_location: true, default_impound_location: true, skip_update: false)
      organization.reload
      expect(organization.default_impound_location).to eq location2
      location.reload
      expect(location.default_impound_location).to be_falsey
      # Also test that it blocks destroying if impound_record is present
      expect(impound_record.reload.location&.id).to eq location.id
      expect { location2.destroy }.to raise_error(/impound/i) # because it's default impound
      expect { location.destroy }.to raise_error(/impound/i) # Because it has impound records
    end
  end
end
