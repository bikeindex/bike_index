require "rails_helper"

RSpec.describe Location, type: :model do
  it_behaves_like "address_recorded"

  describe "set_calculated_attributes" do
    it "strips the non-digit numbers from the phone input" do
      location = FactoryBot.create(:location, phone: "773.83ddp+83(887)")
      expect(location.phone).to eq("77383ddp+83887")
    end

    it "sets address_record organization_id and kind with nested attributes" do
      organization = FactoryBot.create(:organization)
      location = organization.locations.create!(
        name: "Main Office",
        address_record_attributes: {
          street: "123 Main St",
          city: "Chicago",
          country_id: Country.united_states_id,
          skip_geocoding: true
        }
      )
      expect(location.address_record).to be_present
      expect(location.address_record.organization_id).to eq organization.id
      expect(location.address_record.kind).to eq "organization"
      expect(location.address_record.city).to eq "Chicago"
    end
  end

  describe "factory" do
    let(:location) { FactoryBot.create(:location_chicago) }
    it "is correct" do
      expect(location).to be_valid
      expect(location.address_record).to have_attributes(kind: :organization, region_string: "AB",
        region_record_id: nil, country_id: Country.canada_id)
    end
  end

  describe "formatted_address_string" do
    it "returns address from address_record, ignoring blank fields" do
      country = Country.create(name: "Neverland", iso: "NEV")
      state = State.create(country_id: country.id, name: "BullShit", abbreviation: "BS")
      address_record = AddressRecord.create(street: "300 Blossom Hill Dr", city: "Lancaster", region_record_id: state.id, postal_code: "17601", country_id: country.id, skip_geocoding: true)
      location = FactoryBot.create(:location, address_record:)

      expect(location.formatted_address_string(visible_attribute: :street, render_country: true)).to eq("300 Blossom Hill Dr, Lancaster, BS 17601, Neverland")

      address_record.update(street: nil)
      expect(location.formatted_address_string(visible_attribute: :street, render_country: true)).to eq("Lancaster, BS 17601, Neverland")
    end
  end

  describe "org_location_id" do
    it "creates a unique id that references the organization" do
      location = FactoryBot.create(:location)
      expect(location.org_location_id).to eq("#{location.organization_id}_#{location.id}")
    end
  end

  describe "find_or_build_address_record" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:location) { FactoryBot.create(:location, organization:, address_record: nil) }

    context "when no organization address_record exists" do
      it "returns a new AddressRecord with current_country_id" do
        result = location.find_or_build_address_record(current_country_id: Country.united_states_id)
        expect(result).to be_a_new(AddressRecord)
        expect(result.country_id).to eq Country.united_states_id
      end
    end

    context "when organization has an existing address_record" do
      let!(:existing_address_record) { FactoryBot.create(:address_record, organization:) }

      it "returns a new AddressRecord with values from the existing record" do
        result = location.find_or_build_address_record(current_country_id: 999)
        expect(result).to be_a_new(AddressRecord)
        expect(result.country_id).to eq existing_address_record.country_id
        expect(result.region_record_id).to eq existing_address_record.region_record_id
      end
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
