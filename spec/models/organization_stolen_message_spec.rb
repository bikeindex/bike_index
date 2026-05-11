require "rails_helper"

RSpec.describe OrganizationStolenMessage, type: :model do
  it_behaves_like "search_radius_metricable"

  describe "calculated_attributes" do
    let(:organization) { FactoryBot.create(:organization, kind: "law_enforcement") }
    let(:organization_stolen_message) { OrganizationStolenMessage.for(organization) }
    it "uses attributes" do
      expect(organization.search_radius_miles).to eq 50
      expect(Organization.with_stolen_message.pluck(:id)).to eq([])
      expect(organization_stolen_message.reload.organization_id).to eq organization.id
      expect(organization_stolen_message.kind).to eq "area"
      expect(organization_stolen_message.search_radius_miles).to eq OrganizationStolenMessage::DEFAULT_RADIUS_MILES
      organization_stolen_message.update(is_enabled: true, body: "  ", kind: "association")
      expect(organization_stolen_message.is_enabled).to be_falsey
      expect(organization_stolen_message.body).to eq nil
      expect(organization_stolen_message.latitude).to be_blank
      expect(organization_stolen_message.content_added_at).to be_blank
      expect(OrganizationStolenMessage.present.pluck(:id)).to eq([])
      expect(Organization.with_stolen_message.pluck(:id)).to eq([])
    end
    context "organization with location" do
      let(:organization) { FactoryBot.create(:organization, :in_nyc, kind: "bike_manufacturer", search_radius_miles: 94) }
      it "uses location" do
        expect(organization_stolen_message.reload.latitude).to eq organization.location_latitude
        expect(organization_stolen_message.longitude).to eq organization.location_longitude
        expect(organization_stolen_message.search_radius_miles).to eq 10
        expect(organization_stolen_message.kind).to eq "association"
        expect(organization_stolen_message.is_enabled).to be_falsey
        organization_stolen_message.update(is_enabled: true, body: "  Something\n<strong> PARTy</strong>  ", search_radius_miles: 12, latitude: 22, longitude: 22)
        expect(organization_stolen_message.reload.latitude).to eq organization.location_latitude
        expect(organization_stolen_message.longitude).to eq organization.location_longitude
        expect(organization_stolen_message.body).to eq "Something PARTy"
        expect(organization_stolen_message.search_radius_miles).to eq 12
        expect(organization_stolen_message.is_enabled).to be_truthy
        expect(organization_stolen_message.content_added_at).to be_present
        expect(OrganizationStolenMessage.present.pluck(:id)).to eq([organization_stolen_message.id])
        expect(Organization.with_stolen_message.pluck(:id)).to eq([organization.id])
      end
    end
    context "overly long body" do
      let(:target) { "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qu" }
      it "truncates" do
        organization_stolen_message.update(is_enabled: true, body: " #{target} i officia deserunt mollit anim id est laborum.")
        expect(organization_stolen_message.reload.is_enabled).to be_falsey
        expect(organization_stolen_message.body).to eq target
      end
    end
    context "report_url present" do
      let(:organization_stolen_message) { OrganizationStolenMessage.create!(organization_id: organization.id, report_url: "https://example.com", kind: "association") }
      it "also can enable" do
        expect(organization_stolen_message).to be_valid
        expect(organization_stolen_message.can_enable?).to be_truthy
        organization_stolen_message.update(is_enabled: true)
        expect(organization_stolen_message.reload.is_enabled).to be_truthy
        organization_stolen_message.update(is_enabled: false)
        expect(organization_stolen_message.reload.is_enabled).to be_falsey
      end
    end
    context "max search_radius" do
      let(:organization_stolen_message) { OrganizationStolenMessage.create(organization_id: organization.id, search_radius_miles: 9900) }
      it "sets to max search_radius" do
        expect(organization_stolen_message.reload.search_radius_miles).to eq 1000
      end
    end
  end

  describe "for stolen_record" do
    let(:organization) { FactoryBot.create(:organization_with_organization_features, kind: "bike_shop", enabled_feature_slugs: ["organization_stolen_message"]) }
    let!(:organization_default_location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, organization: organization) }
    let!(:organization_stolen_message) { OrganizationStolenMessage.where(organization_id: organization.id).first_or_create }
    let(:attrs) { {kind: "association", is_enabled: true, body: "Something cool"} }
    before { organization_stolen_message.update(attrs) }
    let(:organization2) { FactoryBot.create(:organization) }
    let(:bike) { FactoryBot.create(:bike_organized, :with_stolen_record, :with_address_record, address_in: :new_york, creation_organization: organization) }
    let(:stolen_record) { bike.reload.current_stolen_record }
    let(:bike2) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization2) }
    let(:stolen_record2) { bike2.current_stolen_record }
    it "returns organization_stolen_message, doesn't assign" do
      expect(organization_stolen_message.id).to be_present
      expect(OrganizationStolenMessage.count).to eq 1
      expect(stolen_record).to be_valid
      expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      expect(stolen_record.organization_stolen_message_id).to eq nil
      expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message.id
      expect(stolen_record.reload.organization_stolen_message_id).to eq nil
      # Not association bike doesn't match
      expect(stolen_record2).to be_valid
      expect(OrganizationStolenMessage.for_stolen_record(stolen_record2)&.id).to eq nil
    end
    context "assigned organization_stolen_message_id" do
      let(:organization2) { FactoryBot.create(:organization) }
      let!(:organization_stolen_message2) { OrganizationStolenMessage.create(organization: organization2) }
      it "returns assigned" do
        expect(stolen_record).to be_valid
        expect(organization_stolen_message2).to be_valid
        expect(organization_stolen_message2.is_enabled).to be_falsey
        stolen_record.update(organization_stolen_message: organization_stolen_message2)
        expect(stolen_record.reload.organization_stolen_message.is_enabled).to be_falsey
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message2.id
      end
    end
    context "second association" do
      let(:organization2) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["organization_stolen_message"]) }
      let!(:organization_stolen_message2) { OrganizationStolenMessage.where(organization_id: organization2.id).first_or_create }
      before { organization_stolen_message2.update(attrs) }
      it "returns first", :flaky do
        expect(organization_stolen_message.id).to be_present
        expect(organization_stolen_message2).to be_valid
        expect(OrganizationStolenMessage.count).to eq 2
        bike.bike_organizations.create(organization: organization2)
        expect(stolen_record).to be_valid
        expect(bike.reload.bike_organizations.pluck(:organization_id)).to eq([organization.id, organization2.id])
        expect(stolen_record.organization_stolen_message_id).to eq nil
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message.id
        expect(stolen_record.reload.organization_stolen_message_id).to eq nil
        # And then test the reverse order
        expect(stolen_record2).to be_valid
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record2)&.id).to eq organization_stolen_message2.id
        bike2.bike_organizations.create(organization: organization)
        expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization2.id, organization.id])
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record2)&.id).to eq organization_stolen_message2.id
      end
    end
    context "with an area organization_stolen_message" do
      let(:organization2) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["organization_stolen_message"]) }
      let(:area_attrs) { {kind: "area", is_enabled: true, body: "Something cool", search_radius_miles: 100} }
      let!(:organization_stolen_message2) { OrganizationStolenMessage.where(organization_id: organization2.id).first_or_create }
      before { organization_stolen_message2.update(area_attrs) }
      it "returns area" do
        expect(organization_stolen_message.id).to be_present
        expect(OrganizationStolenMessage.count).to eq 2
        expect(OrganizationStolenMessage.area.pluck(:id)).to eq([organization_stolen_message2.id])
        expect(stolen_record).to be_valid
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(stolen_record.organization_stolen_message_id).to eq nil
        expect(OrganizationStolenMessage.for_coordinates(stolen_record.to_coordinates)&.id).to eq organization_stolen_message2.id
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message2.id
        expect(stolen_record.reload.organization_stolen_message_id).to eq nil
        # Associated bike also matches
        expect(bike2.reload.current_stolen_record_id).to be_present
        expect(bike2.bike_organizations.pluck(:organization_id)).to eq([organization2.id])
        expect(OrganizationStolenMessage.for_coordinates(stolen_record2.to_coordinates)&.id).to eq organization_stolen_message2.id
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record2)&.id).to eq organization_stolen_message2.id
        # Associated bike outside of area still matches
        stolen_record2.update(latitude: 41.86, longitude: -87.65, skip_geocoding: true)
        expect(OrganizationStolenMessage.for_coordinates(stolen_record2.to_coordinates)&.id).to be_blank
        expect(OrganizationStolenMessage.for_stolen_record(stolen_record2)&.id).to eq organization_stolen_message2.id
      end

      context "2 area organization_stolen_message" do
        let(:prospect_park) { {latitude: 40.655135, longitude: -73.9648107} }
        let(:williamsburg) { {latitude: 40.7031836, longitude: -73.9639495} }
        let(:attrs) { area_attrs } # Assigns it to be first
        let(:williamsburg_address) { FactoryBot.create(:address_record, :new_york, williamsburg.merge(skip_geocoding: true)) }
        let!(:organization_default_location) { FactoryBot.create(:location, organization:, address_record: williamsburg_address) }
        it "returns the closer area" do
          expect([organization.reload.default_location.latitude, organization.reload.default_location.longitude]).to eq(williamsburg.values)
          stolen_record.update(prospect_park.merge(skip_geocoding: true))
          expect(stolen_record.reload.to_coordinates).to eq(prospect_park.values)
          expect(organization_stolen_message.id).to be_present
          expect(OrganizationStolenMessage.count).to eq 2
          expect(OrganizationStolenMessage.area.pluck(:id)).to eq([organization_stolen_message.id, organization_stolen_message2.id])
          expect(organization_stolen_message.reload.to_coordinates).to_not eq(organization_stolen_message2.reload.to_coordinates)
          expect(stolen_record).to be_valid
          expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
          expect(stolen_record.organization_stolen_message_id).to eq nil
          expect(OrganizationStolenMessage.for_stolen_record(stolen_record)&.id).to eq organization_stolen_message.id
          # Closer to the Manhattan location
          expect(stolen_record2).to be_valid
          expect(OrganizationStolenMessage.for_stolen_record(stolen_record2)&.id).to eq organization_stolen_message2.id
          # And change the search_radius, so the closer location one no longer contains the area
          organization_stolen_message.update(search_radius_miles: 1)
          # Verify that organization_stolen_message is the closer one
          expect(OrganizationStolenMessage.near(bike.current_stolen_record.to_coordinates).map(&:id)).to eq([organization_stolen_message.id, organization_stolen_message2.id])
          expect(organization_stolen_message.reload.distance_to(stolen_record.to_coordinates)).to be > organization_stolen_message.search_radius_miles
          expect(OrganizationStolenMessage.for_stolen_record(bike.current_stolen_record)&.id).to eq organization_stolen_message2.id
        end
      end
    end
  end
end
