require "rails_helper"

# This concern has a bunch of class methods on it - which are tested here
RSpec.describe BikeSearchable do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }
  let(:multi_query_items) { [manufacturer.search_id, color.search_id, "some other string", "another string"] }
  let(:ip_address) { "127.0.0.1" }
  let(:interpreted_params) { BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address) }
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
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
        end
      end
      context "with vehicle_type" do
        let(:query_params) { {query_items: multi_query_items + ["v_1"]} }
        let(:target_with_cycle_type) { target.merge(cycle_type: :tandem) }
        it "returns" do
          expect(BikeSearchable.send(:searchable_query_items_cycle_type, {query_items: ["v_1"]})).to eq({cycle_type: :tandem})
          expect(BikeSearchable.send(:searchable_query_items_cycle_type, {query_items: ["v_1", "v_0"]})).to eq({cycle_type: :tandem})
          expect(BikeSearchable.send(:searchable_query_items_cycle_type, {cycle_type: :tandem})).to eq({cycle_type: :tandem})
          expect(BikeSearchable.send(:searchable_query_items_cycle_type, {cycle_type: "Cargo Bike (front storage)"})).to eq({cycle_type: :cargo})
          expect(BikeSearchable.send(:searchable_query_items_cycle_type, {cycle_type: "Jibberish"})).to eq({})
          expect(BikeSearchable.send(:searchable_query_items_cycle_type, query_params)).to eq({cycle_type: :tandem})
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target_with_cycle_type
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target_with_cycle_type
        end
      end
      context "with propulsion_type" do
        let(:query_params) { {query_items: multi_query_items + ["p_10"]} }
        let(:target_with_propulsion_type) { target.merge(propulsion_type: :motorized) }
        it "returns" do
          expect(BikeSearchable.send(:searchable_query_items_propulsion_type, {query_items: ["p_10"]})).to eq({propulsion_type: :motorized})
          expect(BikeSearchable.send(:searchable_query_items_propulsion_type, {query_items: ["p_10", "p_10"]})).to eq({propulsion_type: :motorized})
          expect(BikeSearchable.send(:searchable_query_items_propulsion_type, {propulsion_type: :motorized})).to eq({propulsion_type: :motorized})
          expect(BikeSearchable.send(:searchable_query_items_propulsion_type, {query_items: ["p_1"]})).to eq({propulsion_type: :"pedal-assist"})
          expect(BikeSearchable.send(:searchable_query_items_propulsion_type, {propulsion_type: :throttle})).to eq({propulsion_type: :throttle})
          expect(BikeSearchable.send(:searchable_query_items_propulsion_type, {propulsion_type: "jibberish"})).to eq({})
          expect(BikeSearchable.send(:searchable_query_items_propulsion_type, query_params)).to eq({propulsion_type: :motorized})
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target_with_propulsion_type
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target_with_propulsion_type
        end
      end
      context "with passed ids" do
        let(:query_params) { {manufacturer: manufacturer.slug, colors: [color.name], query: "some other string another string"} }
        it "uses the passed ids" do
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
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
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
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
            expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
        context "parsing interpreted_params" do
          let(:query_params) { target.merge(serial: "PPPPXXX") }
          it "returns itself without calling the db for manufacturer" do
            expect(Manufacturer).to_not receive(:friendly_find)
            expect(BikeSearchable.searchable_interpreted_params(interpreted_params, ip: ip_address)).to eq interpreted_params
          end
        end
      end
    end
    context "no query in query_items" do
      let(:query_params) { {query_items: [""], stolenness: "stolen"} }
      let(:target) { {stolenness: "stolen"} }
      it "returns just query" do
        expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
      end
    end
    context "with nil query items" do
      let(:query_params) { {serial: "some serial", query_items: nil, stolenness: "non"} }
      let(:target) { {serial: SerialNormalizer.new(serial: "some serial").normalized, raw_serial: "some serial", stolenness: "non"} }
      it "parses serial" do
        expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target.merge(serial_no_space: target[:serial].tr(" ", ""))
      end
    end
    context "stolenness" do
      context "default" do
        let(:target) { {stolenness: "stolen"} }
        context "nil" do
          let(:query_params) { {} }
          it "returns stolen" do
            expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
        context "unknown string" do
          let(:query_params) { {stolenness: "Not a thing!"} }
          it "returns stolen" do
            expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
        context "stolen" do
          let(:query_params) { {stolenness: "stolen"} }
          it "returns stolen" do
            expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
      end
      context "all" do
        let(:query_params) { {stolenness: "all"} }
        let(:target) { query_params }
        it "parses serial" do
          expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
        end
      end
      context "proximity" do
        context "ignored locations" do
          context "proximity of anywhere" do
            let(:query_params) { {stolenness: "proximity", location: "anywhere", distance: 100} }
            let(:target) { {stolenness: "stolen"} }
            it "returns a non-proximity search" do
              expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
        end
        context "input location" do
          let(:query_params) { {stolenness: "proximity", location: "these parts", distance: "-1"} }
          context "with a distance less 0" do
            let(:target) { {stolenness: "proximity", location: "these parts", distance: 100, bounding_box: bounding_box} }
            it "returns location and distance of 100" do
              expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
          context "with no distance" do
            let(:target) { {stolenness: "proximity", location: "these parts", distance: 100, bounding_box: bounding_box} }
            it "returns location and distance of 100" do
              expect(BikeSearchable.searchable_interpreted_params(query_params.except(:distance), ip: ip_address)).to eq target
            end
          end
          context "with a broken bounding box" do
            let(:nan) { 0.0 / 0 }
            # Override bounding box stub in geocoder_default_location shared_context
            let(:bounding_box) { [nan, nan, nan, nan] }
            let(:target) { {stolenness: "stolen"} }
            it "returns a non-proximity search" do
              expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
        end
        %w[ip you].each do |ip_string|
          context "Reverse geocode IP lookup for location: '#{ip_string}'" do
            let(:query_params) { {stolenness: "proximity", location: ip_string, distance: "twelve "} }
            let(:target) { {stolenness: "proximity", distance: 100, location: nil, bounding_box: bounding_box} }
            it "returns the location and the distance" do
              expect(Geocoder).to receive(:search).with(ip_address) { "STUBBED response" }
              expect(BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
            end
          end
        end
        # TODO: This returns something, because of the stubbing :/
        # context 'a blank ip address for "ip" proximity search' do
        #   let(:query_params) { {stolenness: "proximity", location: "ip", distance: "7 "} }
        #   let(:target) { {stolenness: "stolen"} }
        #   it "returns a non-proximity search" do
        #     expect(BikeSearchable.searchable_interpreted_params(query_params, ip: " ")).to eq target
        #   end
        # end
      end
    end
  end

  describe "selected_query_items_options" do
    context "empty" do
      let(:query_params) { {} }
      context "empty params" do
        it "returns an empty array" do
          expect(BikeSearchable.selected_query_items_options(interpreted_params)).to eq([])
        end
      end
      context "blank values" do
        let(:query_params) { {stolenness: "all", query: "", query_items: []} }
        it "returns an empty array" do
          expect(BikeSearchable.selected_query_items_options(interpreted_params)).to eq([])
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
        expect(BikeSearchable.selected_query_items_options(interpreted_params)).to eq target
      end
    end
    context "unknown manufacturers and colors query" do
      # Instead of erroring, just skip the unknown manufacturers
      let(:query_params) { {serial: "XXX8c8c", query_items: ["m_1000", "c_999", "special handlebars"]} }
      let(:target) { ["special handlebars"] }
      it "returns the query items without erroring" do
        expect(BikeSearchable.selected_query_items_options(interpreted_params)).to eq target
      end
    end
    context "cycle_type" do
      let(:target) do
        {
          category: "cycle_type",
          id: 15,
          priority: 900,
          search_id: "v_15",
          slug: "pedi-cab",
          text: "Pedi Cab (rickshaw)"
        }
      end
      it "returns target" do
        result = BikeSearchable.selected_query_items_options({cycle_type: "pedi-cab", stolenness: "all"})
        expect(result.count).to eq 1
        expect(result.first).to match_hash_indifferently target
      end
    end
  end
end
