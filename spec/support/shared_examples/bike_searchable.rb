require "rails_helper"

RSpec.shared_examples "bike_searchable" do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }
  let(:multi_query_items) { [manufacturer.search_id, color.search_id, "some other string", "another string"] }
  let(:ip_address) { "127.0.0.1" }
  let(:interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: ip_address) }
  include_context :geocoder_stubbed_bounding_box

  describe "searchable_interpreted_params" do
    context "multiple query_items strings" do
      let(:target) do
        {
          manufacturer: manufacturer.id,
          colors: [color.id],
          query: "some other string another string",
          stolenness: "stolen"
        }
      end
      context "with query_params" do
        let(:query_params) { {serial: nil, query_items: multi_query_items} }
        it "parses search_ids for manufacturers and colors" do
          expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
        end
      end
      context "with passed ids" do
        let(:query_params) { {manufacturer: manufacturer.slug, colors: [color.name], query: "some other string another string"} }
        it "uses the passed ids" do
          expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
        end
      end
    end
    context "multiple manufacturer_id and color_ids" do
      let(:manufacturer2) { FactoryBot.create(:manufacturer) }
      let(:color2) { FactoryBot.create(:color) }
      let(:target) do
        {
          manufacturer: [manufacturer.id, manufacturer2.id],
          colors: [color.id, color2.id],
          query: "some other string another string",
          stolenness: "all"
        }
      end
      context "integer ids in query_items" do
        let(:query_items) { multi_query_items + [manufacturer2.search_id, color2.search_id] }
        let(:query_params) { {query_items: query_items, stolenness: "all"} }
        it "returns them all" do
          expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
        end
      end
      context "name and slug for explicit manufacturer_id, color_ids and query" do
        let(:query_params) do
          {
            query_items: multi_query_items,
            manufacturer: [manufacturer.slug, manufacturer2.name],
            colors: [color.id, color2.name],
            query: "some other string another string",
            stolenness: "all"
          }
        end
        context "first pass" do
          it "finds the explicit ids and query" do
            expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
        context "parsing interpreted_params" do
          let(:query_params) { target.merge(serial: "PPPPXXX") }
          it "returns itself without calling the db for manufacturer" do
            expect(Manufacturer).to_not receive(:friendly_find)
            expect(Bike.searchable_interpreted_params(interpreted_params, ip: ip_address)).to eq interpreted_params
          end
        end
      end
    end
    context "no query in query_items" do
      let(:query_params) { {query_items: [""], stolenness: "stolen"} }
      let(:target) { {stolenness: "stolen"} }
      it "returns just query" do
        expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
      end
    end
    context "with nil query items" do
      let(:query_params) { {serial: "some serial", query_items: nil, stolenness: "non"} }
      let(:target) { {serial: SerialNormalizer.new(serial: "some serial").normalized, raw_serial: "some serial", stolenness: "non"} }
      it "parses serial" do
        expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
      end
    end
    context "stolenness" do
      context "default" do
        let(:target) { {stolenness: "stolen"} }
        context "nil" do
          let(:query_params) { {} }
          it "returns stolen" do
            expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
        context "unknown string" do
          let(:query_params) { {stolenness: "Not a thing!"} }
          it "returns stolen" do
            expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
        context "stolen" do
          let(:query_params) { {stolenness: "stolen"} }
          it "returns stolen" do
            expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
      end
      context "all" do
        let(:query_params) { {stolenness: "all"} }
        let(:target) { query_params }
        it "parses serial" do
          expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
        end
      end
      context "proximity" do
        context "ignored locations" do
          context "proximity of anywhere" do
            let(:query_params) { {stolenness: "proximity", location: "anywhere", distance: 100} }
            let(:target) { {stolenness: "stolen"} }
            it "returns a non-proximity search" do
              expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
        end
        context "input location" do
          let(:query_params) { {stolenness: "proximity", location: "these parts", distance: "-1"} }
          context "with a distance less 0" do
            let(:target) { {stolenness: "proximity", location: "these parts", distance: 100, bounding_box: bounding_box} }
            it "returns location and distance of 100" do
              expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
          context "with no distance" do
            let(:target) { {stolenness: "proximity", location: "these parts", distance: 100, bounding_box: bounding_box} }
            it "returns location and distance of 100" do
              expect(Bike.searchable_interpreted_params(query_params.except(:distance), ip: ip_address)).to eq target
            end
          end
          context "with a broken bounding box" do
            let(:nan) { 0.0 / 0 }
            # Override bounding box stub in geocoder_default_location shared_context
            let(:bounding_box) { [nan, nan, nan, nan] }
            let(:target) { {stolenness: "stolen"} }
            it "returns a non-proximity search" do
              expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
        end
        %w[ip you].each do |ip_string|
          context "Reverse geocode IP lookup for location: '#{ip_string}'" do
            let(:query_params) { {stolenness: "proximity", location: ip_string, distance: "twelve "} }
            let(:target) { {stolenness: "proximity", distance: 100, location: "STUBBED response", bounding_box: bounding_box} }
            it "returns the location and the distance" do
              expect(Geocoder).to receive(:search).with(ip_address) { "STUBBED response" }
              expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
        end
        context 'a blank ip address for "ip" proximity search' do
          let(:query_params) { {stolenness: "proximity", location: "ip", distance: "7 "} }
          let(:target) { {stolenness: "stolen"} }
          it "returns a non-proximity search" do
            expect(Bike.searchable_interpreted_params(query_params, ip: " ")).to eq target
          end
        end
      end
    end
  end

  describe "selected_query_items_options" do
    context "empty" do
      let(:query_params) { {} }
      context "empty params" do
        it "returns an empty array" do
          expect(Bike.selected_query_items_options(interpreted_params)).to eq([])
        end
      end
      context "blank values" do
        let(:query_params) { {stolenness: "all", query: "", query_items: []} }
        it "returns an empty array" do
          expect(Bike.selected_query_items_options(interpreted_params)).to eq([])
        end
      end
    end
    context "functioning query" do
      let(:query_params) { {serial: nil, query_items: multi_query_items} }
      let(:target) do
        [
          "some other string another string",
          manufacturer.autocomplete_result_hash,
          color.autocomplete_result_hash
        ]
      end
      it "returns the query items hashes (for display in HTML)" do
        expect(Bike.selected_query_items_options(interpreted_params)).to eq target
      end
    end
    context "unknown manufacturers and colors query" do
      # Instead of erroring, just skip the unknown manufacturers
      let(:query_params) { {serial: "XXX8c8c", query_items: ["m_1000", "c_999", "special handlebars"]} }
      let(:target) { ["special handlebars"] }
      it "returns the query items without erroring" do
        expect(Bike.selected_query_items_options(interpreted_params)).to eq target
      end
    end
  end
  describe "search" do
    context "color_ids of primary, secondary and tertiary" do
      let(:color2) { FactoryBot.create(:color) }
      let(:bike1) { FactoryBot.create(:bike, primary_frame_color: color, updated_at: Time.current - 3.months) }
      let(:bike2) { FactoryBot.create(:bike, secondary_frame_color: color, tertiary_frame_color: color2, updated_at: Time.current - 2.weeks) }
      let(:bike3) { FactoryBot.create(:bike, tertiary_frame_color: color, manufacturer: manufacturer) }
      let(:all_color_ids) do
        [
          bike1.primary_frame_color_id,
          bike2.primary_frame_color_id,
          bike3.primary_frame_color_id,
          bike1.secondary_frame_color_id,
          bike2.secondary_frame_color_id,
          bike3.secondary_frame_color_id,
          bike1.tertiary_frame_color_id,
          bike2.tertiary_frame_color_id,
          bike3.tertiary_frame_color_id
        ]
      end
      before do
        expect(all_color_ids.count(color.id)).to eq 3 # Each bike has color only once
      end
      context "single color" do
        let(:query_params) { {colors: [color.id], stolenness: "all"} }
        it "matches bikes with the given color" do
          expect(bike1.listing_order < bike2.listing_order).to be_truthy
          expect(bike2.listing_order < bike3.listing_order).to be_truthy
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike3.id, bike2.id, bike1.id])
        end
      end
      context "second color" do
        let(:query_params) { {colors: [color.id, color2.id], stolenness: "all"} }
        it "matches just the bike with both colors" do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike2.id])
        end
      end
      context "and manufacturer_id" do
        let(:query_params) { {colors: [color.id], manufacturer: manufacturer.id, stolenness: "all"} }
        it "matches just the bike with the matching manufacturer" do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike3.id])
        end
      end
    end
    context "serial" do
      before do
        expect(bike).to be_present
      end
      context "stood-ffer" do
        let(:bike) { FactoryBot.create(:bike, serial_number: "st00d-ffer") }
        context "full homoglyph match" do
          let(:query_params) { {serial: "STood ffer", stolenness: "all"} }
          it "finds matching bikes" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
          end
        end
        context "partial homoglyph match" do
          let(:query_params) { {serial: "ST0oD", stolenness: "all"} }
          it "finds matching bikes" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
          end
        end
      end
      context "reversed serial" do
        let(:bike) { FactoryBot.create(:bike, serial_number: "K10DY00047-bkd") }
        let(:query_params) { {serial: "bkd-K1oDYooo47", stolenness: "all"} }
        it "fulls text search" do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
        end
      end
    end
    context "query" do
      it "selects matching the query" do
        bike1 = FactoryBot.create(:bike, description: "Booger")
        bike2 = FactoryBot.create(:bike)
        expect(bike1).to be_valid
        expect(bike2).to be_valid

        interpreted_params = Bike.searchable_interpreted_params(
          {query: "booger", stolenness: "all"},
          ip: "127.0.0.1"
        )
        results = Bike.search(interpreted_params)

        expect(results.pluck(:id)).to eq([bike1.id])
      end
    end
    context "stolenness" do
      context "non-proximity" do
        let(:stolen_bike) { FactoryBot.create(:stolen_bike) }
        let(:non_stolen_bike) { FactoryBot.create(:bike) }
        before do
          expect([stolen_bike, non_stolen_bike].size).to eq 2
        end
        context "stolen_search" do
          let(:query_params) { {stolenness: "stolen"} }
          it "only stolen bikes" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
          end
        end
        context "non_stolen search" do
          let(:query_params) { {stolenness: "non"} }
          it "only non_stolen" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([non_stolen_bike.id])
          end
        end
        context "all" do
          let(:query_params) { {stolenness: "all"} }
          it "returns all bikes" do
            ids = Bike.search(interpreted_params).pluck(:id)
            expect(ids.count).to eq 2
            expect(ids.include?(stolen_bike.id)).to be_truthy
            expect(ids.include?(non_stolen_bike.id)).to be_truthy
          end
        end
      end
      context "proximity" do
        it "returns bikes near the requested location" do
          bike1 = FactoryBot.create(:stolen_bike_in_amsterdam)
          bike2 = FactoryBot.create(:stolen_bike_in_nyc)
          expect(bike1.longitude).to_not eq(bike2.longitude)

          interpreted_params = Bike.searchable_interpreted_params(
            {stolenness: "proximity", location: "New York, NY", distance: 200},
            ip: "127.0.0.1"
          )
          results = Bike.search(interpreted_params)

          expect(results.pluck(:id)).to eq([bike2.id])
        end
      end
    end
    describe "scoped bike" do
      context "organization bike" do
        let(:interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: "d") }

        let(:bike1) { FactoryBot.create(:bike) }
        let(:bike2) { FactoryBot.create(:bike_organized) }
        let(:organization) { bike2.organizations.first }
        let(:query_params) { {stolenness: "all"} }
        before do
          expect([bike1, bike2].size).to eq 2
          expect(organization.bikes.pluck(:id)).to eq([bike2.id])
        end
        it "only finds bikes in the organization" do
          expect(organization.bikes.search(interpreted_params).pluck(:id)).to eq([bike2.id])
        end
      end
    end
  end

  describe "search_close_serials" do
    let(:stolen_bike) { FactoryBot.create(:stolen_bike, serial_number: "O|ILSZB-111JJJG8", manufacturer: manufacturer) }
    let(:non_stolen_bike) { FactoryBot.create(:bike, serial_number: "O|ILSZB-111JJJJJ") }
    before do
      expect([non_stolen_bike, stolen_bike].size).to eq 2
    end
    context "no serial param" do
      let(:query_params) { {query_items: [manufacturer.search_id], stolenness: "non"} }
      it "returns nil" do
        expect(Bike.search_close_serials(interpreted_params)).to be_blank
      end
    end
    context "exact normalized serial" do
      let(:query_params) { {serial: "11I528-111JJJJJ", stolenness: "all"} } # Because drops leading zeros
      it "matches only non-exact" do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context "serial with spaces rather than dashes" do
      let(:query_params) { {serial: "11I528 111JJJJJ", stolenness: "all"} }
      it "matches only non-exact" do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context "spaces" do
      let(:stolen_bike) { FactoryBot.create(:stolen_bike, serial_number: "O|I LSZB 111J JJJJ", manufacturer: manufacturer) }
      context "dashes not spaces" do
        let(:query_params) { {serial: "011-I528-111J-JJJJ", stolenness: "all"} }
        it "matches only non-exact" do
          expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to match_array([stolen_bike.id, non_stolen_bike.id])
        end
      end
      context "no spaces" do
        let(:query_params) { {serial: "11I528111JJJJJ", stolenness: "all"} }
        it "matches only non-exact" do
          expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to match_array([stolen_bike.id, non_stolen_bike.id])
        end
      end
    end
    context "close serial with stolenness" do
      let(:query_params) { {serial: "011I528-111JJJk", stolenness: "non"} }
      it "returns matching stolenness" do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([non_stolen_bike.id])
      end
    end
    context "close serial with query items" do
      let(:query_params) { {serial: "011I528-111JJJk", query_items: [manufacturer.search_id], stolenness: "all"} }
      it "returns matching" do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context "close serial on organization bikes" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:query_params) { {serial: "011I528-111JJJk", stolenness: "all"} }
      before do
        FactoryBot.create(:bike_organization, bike: stolen_bike, organization: organization)
        stolen_bike.update_attribute :creation_organization_id, organization.id
        expect(organization.bikes.pluck(:id)).to eq([stolen_bike.id])
      end
      it "returns matching stolenness" do
        expect(organization.bikes.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
  end
end
