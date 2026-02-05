require "rails_helper"

RSpec.describe AddressRecord, type: :model do
  describe "factory" do
    let(:address_record) { FactoryBot.create(:address_record) }
    it "is valid" do
      expect(address_record).to be_valid
      expect(address_record.region).to eq "CA"
      expect(address_record.include_country?).to be_falsey
      expect(address_record.formatted_address_string).to eq "Davis, CA 95616"
      expect(address_record.formatted_address_string(render_country: true)).to eq "Davis, CA 95616, United States"

      expect(address_record.formatted_address_string(render_country: :if_different)).to eq "Davis, CA 95616"
      expect(address_record.formatted_address_string(render_country: :if_different, current_country_iso: "CA"))
        .to eq "Davis, CA 95616, United States"
      # include_country defaults to :if_different if not matching
      expect(address_record.formatted_address_string(render_country: "something")).to eq "Davis, CA 95616"
    end
    context "in_amsterdam" do
      let(:address_record) { FactoryBot.create(:address_record, :amsterdam) }
      it "is valid" do
        expect(address_record).to be_valid
        expect(address_record.region).to eq "North Holland"
        expect(address_record.formatted_address_string(render_country: true)).to eq "Amsterdam, North Holland 1012, Netherlands"
        expect(address_record.formatted_address_string).to eq "Amsterdam, North Holland 1012, Netherlands"
        expect(address_record.formatted_address_string(current_country_iso: "NL")).to eq "Amsterdam, North Holland 1012"
        # NOTE: actual correct formatted address: Spuistraat 134afd.Gesch., 1012 VB Amsterdam, Netherlands
        expect(address_record.formatted_address_string(visible_attribute: "street")).to eq "Spuistraat 134afd.Gesch., Amsterdam, North Holland 1012, Netherlands"
      end
    end
    context "with street_2" do
      let(:address_record) do
        FactoryBot.create(:address_record, :davis, street: "1233 Howard St", street_2: "Mechanics shop",
          city: "San Francisco", postal_code: "94103")
      end
      it "is valid" do
        expect(address_record).to be_valid
        expect(address_record.region).to eq "CA"
        expect(address_record.formatted_address_string(render_country: true)).to eq "San Francisco, CA 94103, United States"
        expect(address_record.formatted_address_string).to eq "San Francisco, CA 94103"
        expect(address_record.formatted_address_string(visible_attribute: "street"))
          .to eq "1233 Howard St, Mechanics shop, San Francisco, CA 94103"
      end
    end
  end

  describe "attrs_to_duplicate" do
    let!(:obj) { FactoryBot.create(:parking_notification_organized) }

    let(:target_attrs) do
      {
        user_id: obj.user_id,
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
          postal_code: "AB T6G 2B3",
          city: "Edmonton",
          region_record_id: obj.address_record.region_record_id,
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

  describe "assignment" do
    let(:address_record) do
      AddressRecord.create(street: "   ", city: "\n", postal_code:, region_string:, country_id:, skip_geocoding:)
    end
    let(:region_string) { "California " }
    let(:country_id) { Country.united_states.id }
    let(:postal_code) { " 95616" }
    let!(:region_record_id) { FactoryBot.create(:state_california).id }
    let(:skip_geocoding) { true }
    let(:target_attrs) do
      {
        region_record_id:,
        region_string: nil,
        postal_code: postal_code.strip,
        street: nil,
        city: nil,
        latitude: nil,
        longitude: nil
      }
    end
    include_context :geocoder_real

    it "strips and removes blanks" do
      expect(address_record).to be_valid

      expect(address_record.reload).to match_hash_indifferently target_attrs
    end

    context "with geocode" do
      let(:skip_geocoding) { false }
      let(:target_attrs) do
        {
          region_record_id:,
          region_string: nil,
          postal_code: "95616",
          street: nil,
          city: "Davis",
          latitude: 38.5474428,
          longitude: -121.7765309
        }
      end

      it "geocodes" do
        VCR.use_cassette("address-record-assignment_geocode") do
          expect(address_record).to be_valid

          expect(address_record.reload).to match_hash_indifferently target_attrs
        end
      end

      context "with an update" do
        it "overwrites the latitude and longitude" do
          VCR.use_cassette("address-record-assignment_geocode") do
            expect(address_record).to be_valid

            expect(address_record.reload).to match_hash_indifferently target_attrs
          end

          # not wrapped in VCR, so will error if it attempts to geocode
          address_record.reload.update(kind: :marketplace_listing, publicly_visible_attribute: :city, user_id: 121212)

          VCR.use_cassette("address-record-assignment_geocode-again") do
            address_record.update(street: "100 Shields Ave")

            expect(address_record.reload.latitude).to_not eq target_attrs[:latitude]
          end
        end
      end
    end

    context "Canada, force geocoding" do
      let(:region_string) { "  " }
      let!(:region_record_id) { nil }
      let(:postal_code) { "T4N4E4" }
      let(:country_id) { Country.canada_id }
      let(:target_attrs) do
        {
          region_record_id: nil,
          region_string: "AB",
          postal_code: "T4N 4E4",
          street: nil,
          city: "Red Deer",
          latitude: 52.2977406,
          longitude: -113.812812
        }
      end
      it "updates with force update" do
        expect(address_record).to be_valid
        # postal_code is formatted by Geocodeable.format_postal_code
        expect(address_record.reload).to match_hash_indifferently({postal_code: "T4N 4E4", region_string: nil, city: nil})

        VCR.use_cassette("address-record-assignment_geocode-canada") do
          address_record.update(force_geocoding: true)

          expect(address_record.reload).to match_hash_indifferently target_attrs
        end
      end
    end
  end

  describe "formatted_address_string" do
    let(:address_record) { FactoryBot.build(:address_record, :vancouver, publicly_visible_attribute:) }
    let(:publicly_visible_attribute) { :street }
    let(:country_id) { address_record.country_id }
    let(:target) { "278 W Broadway, Vancouver, BC V5Y 1P5, Canada" }
    let(:target_no_street) { target.gsub("278 W Broadway, ", "") }

    it "returns formatted_address_string" do
      expect(address_record.formatted_address_string).to eq target
      expect(address_record.formatted_address_string(render_country: true)).to eq target
      expect(address_record.formatted_address_string(current_country_iso: "mx")).to eq target
      target_no_country = target.gsub(", Canada", "")
      expect(address_record.formatted_address_string(current_country_iso: "ca")).to eq target_no_country
      expect(address_record.formatted_address_string(current_country_id: country_id)).to eq target_no_country
    end

    context "publicly_visible_attribute: :postal_code" do
      let(:publicly_visible_attribute) { :postal_code }
      it "returns without street, unless overridden" do
        expect(address_record.formatted_address_string).to eq target.gsub("278 W Broadway, ", "")
        expect(address_record.formatted_address_string(visible_attribute: :street)).to eq target
      end
    end

    context "publicly_visible_attribute: :city" do
      let(:publicly_visible_attribute) { :city }
      it "returns without street or postal_code, unless overridden" do
        expect(address_record.formatted_address_string).to eq target_no_street.gsub(" V5Y 1P5", "")
        expect(address_record.formatted_address_string(visible_attribute: :street)).to eq target
        expect(address_record.formatted_address_string(visible_attribute: :postal_code)).to eq target_no_street
      end
    end
  end

  describe "country" do
    let(:country) { "US" }
    let(:address_record) { FactoryBot.build(:address_record, country_id: nil) }
    before { address_record.country = country }

    it "assigns" do
      expect(Country.united_states).to be_present
      expect(address_record.save).to be_truthy
      expect(address_record.reload.country_id).to eq Country.united_states_id
    end
    context "country: CA" do
      let(:country) { "CA" }
      it "assigns" do
        expect(Country.canada).to be_present
        expect(address_record.save).to be_truthy
        expect(address_record.reload.country_id).to eq Country.canada_id
      end
    end
  end
end
