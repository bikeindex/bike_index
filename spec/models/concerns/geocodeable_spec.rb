require "rails_helper"

# This concern has class methods on it - which are tested here
RSpec.describe Geocodeable do
  describe "attrs_to_duplicate" do
    let!(:obj) { FactoryBot.create(:parking_notification_organized) }

    let(:target_attrs) do
      {
        street: "278 Broadway",
        city: "New York",
        postal_code: "10007",
        latitude: 40.7143528,
        longitude: -74.0059731,
        region_record_id: nil,
        country_id: Country.united_states_id,
        skip_geocoding: true,
        skip_callback_job: true
      }
    end

    it "returns target attrs" do
      expect(described_class.attrs_to_duplicate(obj)).to match_hash_indifferently target_attrs
    end

    context "with address_record" do
      let!(:obj) { FactoryBot.create(:user, :with_address_record, address_in: :edmonton) }
      let(:target_attrs) do
        {
          latitude: 53.5069377,
          longitude: -113.5508765,
          street: "9330 Groat Rd NW",
          street_2: nil,
          postal_code: "T6G 2B3",
          city: "Edmonton",
          region_record_id: nil,
          region_string: "AB",
          country_id: Country.canada_id,
          skip_geocoding: true,
          skip_callback_job: true
        }
      end

      it "returns target attrs" do
        expect(described_class.attrs_to_duplicate(obj)).to match_hash_indifferently target_attrs
      end

      context "passed address_record" do
        let!(:obj) { FactoryBot.create(:bike, :with_address_record, address_in: :edmonton) }
        it "returns target_attrs" do
          expect(described_class.attrs_to_duplicate(obj.address_record)).to match_hash_indifferently target_attrs
        end
      end
    end

    context "passed obj without address" do
      let!(:obj) { FactoryBot.create(:user) }
      it "returns target_attrs" do
        expect(described_class.attrs_to_duplicate(obj)).to eq({})
      end
    end
  end
end
