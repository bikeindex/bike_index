require 'spec_helper'

RSpec.shared_examples 'bike_searchable' do
  # This is a concern not to share code across models, but to seperate all the logic
  # into one file and reduce the size of the enormous Bike model
  let(:geocoded_location) { [{ data: default_location, cache_hit: nil }].as_json } # in spec_helper
  let(:manufacturer) { FactoryGirl.create(:manufacturer) }
  let(:color) { FactoryGirl.create(:color) }
  let(:multi_query_items) { [manufacturer.search_id, color.search_id, 'some other string', 'another string'] }
  let(:interpreted_params) { Bike.searchable_interpreted_params(query_params) }

  describe 'interpreted_query_items' do
    context 'with multiple query_items strings' do
      let(:query_params) { { serial: nil, query_items: multi_query_items } }
      let(:target) do
        {
          manufacturer_ids: [manufacturer.id],
          color_ids: [color.id],
          query: 'some other string another string'
        }
      end
      context 'with query_params' do
        it 'parses search_ids for manufacturers and colors' do
          expect(Bike.searchable_interpreted_params(query_params)).to eq target
        end
      end
      context 'with passed ids' do
        it 'uses the passed ids' do
          expect(Bike.searchable_interpreted_params(target)).to eq target
        end
      end
    end
    context 'multiple manufacturer_ids and color_ids' do
      let(:manufacturer_2) { FactoryGirl.create(:manufacturer) }
      let(:color_2) { FactoryGirl.create(:color) }
      let(:query_items) { multi_query_items + [manufacturer_2.search_id, color_2.search_id] }
      let(:query_params) { { query_items: query_items } }
      let(:target) do
        {
          manufacturer_ids: [manufacturer.id, manufacturer_2.id],
          color_ids: [color.id, color_2.id],
          query: 'some other string another string'
        }
      end
      it 'returns returns them all' do
        expect(Bike.searchable_interpreted_params(query_params)).to eq target
      end
    end
    context 'just query in query_items' do
      let(:query_params) { { query_items: ['something'] } }
      let(:target) { { query: 'something' } }
      it 'returns just query' do
        expect(Bike.searchable_interpreted_params(query_params)).to eq target
      end
    end
    context 'with nil query items' do
      let(:query_params) { { serial: 'some serial', query_items: nil } }
      let(:target) { { normalized_serial: SerialNormalizer.new(serial: 'some serial').normalized } }
      it 'parses serial' do
        expect(Bike.searchable_interpreted_params(query_params)).to eq target
      end
    end
    context 'stolenness proximity' do
      include_context :geocoder_default_location
      context 'with a proximity radius less than 1' do
        let(:query_params) { { stolenness: 'proximity', proximity: 'these parts', distance: '-1' } }
        let(:target) { { stolenness: 'proximity', location: 'these parts', distance: 100 } }
        it 'returns location and distance of 100' do
          expect(Bike.searchable_interpreted_params(query_params)).to eq target
        end
      end
      context 'proximity of anywhere' do
        let(:query_params) { { stolenness: 'proximity', proximity: 'anywhere', distance: 100 } }
        let(:target) { { stolenness: 'stolen' } }
        it 'returns a non-proximity search' do
          expect(Bike.searchable_interpreted_params(query_params)).to eq target
        end
      end
      context 'proximity of empty string' do
        let(:query_params) { { stolenness: 'proximity', proximity: '     ', distance: 100 } }
        let(:target) { { stolenness: 'stolen' } }
        it 'returns a non-proximity search' do
          expect(Bike.searchable_interpreted_params(query_params)).to eq target
        end
      end
      %w(ip you).each do |ip_string|
        context "Reverse geocode IP lookup for proximity: '#{ip_string}'" do
          let(:query_params) { { stolenness: 'proximity', proximity: ip_string, distance: '7 ' } }
          let(:target) { { stolenness: 'proximity', distance: 7, location: 'STUBBED response' } }
          let(:ip_address) { '127.0.0.1' }
          it 'returns the location and the distance' do
            expect(Geocoder).to receive(:search).with(ip_address) { 'STUBBED response' }
            expect(Bike.searchable_interpreted_params(query_params, ip: ip_address)).to eq target
          end
        end
      end
      context 'without an ip address for "ip" proximity search' do
        let(:query_params) { { stolenness: 'proximity', proximity: 'ip', distance: '7 ' } }
        let(:target) { { stolenness: 'stolen' } }
        it 'returns a non-proximity search' do
          expect(Bike.searchable_interpreted_params(query_params)).to eq target
        end
      end
    end
  end

  describe 'query_items' do
    context 'functioning query' do
      let(:query_params) { { serial: nil, query_items: multi_query_items } }
      let(:target) do
        [
          'some other string another string',
          manufacturer.autocomplete_result_hash,
          color.autocomplete_result_hash
        ]
      end
      it 'returns the query items hashes (for display in HTML)' do
        expect(Bike.selected_query_items(query_params)).to eq target
      end
    end
    context 'unknown manufacturers and colors query' do
      # Instead of erroring, just skip the unknown manufacturers
      let(:query_params) { { serial: 'XXX8c8c', query_items: ['m_1000', 'c_999', 'special handlebars'] } }
      let(:target) { ['special handlebars'] }
      it 'returns the query items without erroring' do
        expect(Bike.selected_query_items(query_params)).to eq target
      end
    end
  end

  describe 'search' do
    context 'color_ids of primary, secondary and tertiary' do
      let(:bike_1) { FactoryGirl.create(:bike, primary_frame_color: color) }
      let(:bike_2) { FactoryGirl.create(:bike, secondary_frame_color: color) }
      let(:bike_3) { FactoryGirl.create(:bike, tertiary_frame_color: color, manufacturer: manufacturer) }
      let(:all_color_ids) do
        [
          bike_1.primary_frame_color_id,
          bike_2.primary_frame_color_id,
          bike_3.primary_frame_color_id,
          bike_1.secondary_frame_color_id,
          bike_2.secondary_frame_color_id,
          bike_3.secondary_frame_color_id,
          bike_1.tertiary_frame_color_id,
          bike_2.tertiary_frame_color_id,
          bike_3.tertiary_frame_color_id
        ]
      end
      before do
        expect(all_color_ids.count(color.id)).to eq 3 # Each bike has color only once
      end
      context 'single color' do
        let(:query_params) { { color_ids: [color.id] } }
        it 'matches bikes with the given color' do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike_1.id, bike_2.id, bike_3.id])
        end
      end
      context 'second color' do
        let(:query_params) { { color_ids: [color.id, bike_2.primary_frame_color.id] } }
        it 'matches just the bike with both colors' do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike_2.id])
        end
      end
      context 'and manufacturer_ids' do
        let(:query_params) { { color_ids: [color.id], manufacturer_ids: manufacturer.id } }
        it 'matches just the bike with the matching manufacturer' do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike_3.id])
        end
      end
    end
    context 'serial' do
      before do
        expect(bike).to be_present
      end
      context 'stood-ffer' do
        let(:bike) { FactoryGirl.create(:bike, serial_number: 'st00d-ffer') }
        context 'full homoglyph match' do
          let(:query_params) { { serial: 'STood ffer' } }
          it 'finds matching bikes' do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
          end
        end
        context 'partial homoglyph match' do
          let(:query_params) { { serial: 'ST0oD' } }
          it 'finds matching bikes' do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
          end
        end
      end
      context 'reversed serial' do
        let(:bike) { FactoryGirl.create(:bike, serial_number: 'K10DY00047-bkd') }
        let(:query_params) { { serial: 'bkd-K1oDYooo47' } }
        it 'fulls text search' do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
        end
      end
    end
    context 'query' do
      let(:bike) { FactoryGirl.create(:bike, description: 'Booger') }
      let(:query_params) { { query: 'booger' } }
      before do
        expect(bike).to be_present
      end
      it 'selects matching the query' do
        expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
      end
    end
    context 'stolenness' do
      context 'non-proximity' do
        let(:stolen_bike) { FactoryGirl.create(:stolen_bike) }
        let(:non_stolen_bike) { FactoryGirl.create(:bike) }
        before do
          expect([stolen_bike, non_stolen_bike].size).to eq 2
        end
        context 'stolen_search' do
          let(:query_params) { { stolenness: 'stolen' } }
          it 'only stolen bikes' do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
          end
        end
        context 'non_stolen search' do
          let(:query_params) { { stolenness: 'non' } }
          it 'only non_stolen' do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([non_stolen_bike.id])
          end
        end
        context 'neither set' do
          let(:query_params) { { stolenness: '' } }
          it 'returns all bikes' do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([stolen_bike.id, non_stolen_bike.id])
          end
        end
      end
      context 'proximity' do
        include_context :geocoder_default_location
        let(:bike_1) { FactoryGirl.create(:stolen_bike, latitude: default_location[:latitude], longitude: default_location[:longitude]) }
        let(:stolen_record_1) { bike_1.find_current_stolen_record }
        let(:bike_2) { FactoryGirl.create(:stolen_bike, latitude: 41.8961603, longitude: -87.677215) }
        let(:stolen_record_2) { bike_2.find_current_stolen_record }
        let(:query_params) { { stolenness: 'proximity', proximity: 'New York, NY', distance: 200 } }
        before do
          expect(bike_2.stolen_lat).to_not eq stolen_record_1[:latitude]
        end
        it 'finds the bike where we want it to be' do
          expect(Geocoder::Calculations).to receive(:bounding_box) { [39.989124784445764, -74.96065051723293, 41.43644261555424, -73.05123208276707] }
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike_1.id])
        end
      end
    end
  end
  describe 'search_with_fuzzy_serial' do
    let(:stolen_bike) { FactoryGirl.create(:stolen_bike, serial_number: 'O|ILSZB-111JJJG8', manufacturer: manufacturer) }
    let(:non_stolen_bike) { FactoryGirl.create(:bike, serial_number: 'O|ILSZB-111JJJJJ') }
    before do
      expect([non_stolen_bike, stolen_bike].size).to eq 2
    end
    context 'no serial param' do
      let(:query_params) { { query_items: [manufacturer.search_id], stolenness: 'non' } }
      it 'returns nil' do
        expect(Bike.search_close_serials(interpreted_params)).to eq([])
      end
    end
    context 'exact normalized serial' do
      let(:query_params) { { serial: '11I528-111JJJJJ' } } # Because drops leading zeros
      it 'matches only non-exact' do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context 'close serial with stolenness' do
      let(:query_params) { { serial: '011I528-111JJJk', stolenness: 'non' } }
      it 'returns matching stolenness' do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([non_stolen_bike.id])
      end
    end
    context 'close serial with query items' do
      let(:query_params) { { serial: '011I528-111JJJk', query_items: [manufacturer.search_id] } }
      it 'returns matching' do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
  end
end
