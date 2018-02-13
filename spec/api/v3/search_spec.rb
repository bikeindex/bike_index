require 'spec_helper'

describe 'Search API V3' do
  # For the time being, only count is implemented
  let(:manufacturer) { FactoryGirl.create(:manufacturer) }
  let(:color) { FactoryGirl.create(:color) }
  describe '/' do
    let!(:bike) { FactoryGirl.create(:bike, manufacturer: manufacturer) }
    let!(:bike_2) { FactoryGirl.create(:stolen_bike, manufacturer: manufacturer) }
    let(:query_params) { { query_items: [manufacturer.search_id] } }
    context 'with per_page' do
      it 'returns matching bikes, defaults to stolen' do
        expect(Bike.count).to eq 2
        get '/api/v3/search', query_params.merge(per_page: 1), format: :json
        expect(response.header['Total']).to eq('1')
        result = JSON.parse(response.body)
        expect(result['bikes'][0]['id']).to eq bike_2.id
      end
    end
  end
  describe '/close_serials' do
    let!(:bike) { FactoryGirl.create(:bike, manufacturer: manufacturer, serial_number: 'something') }
    let(:query_params) { { serial: 'somethind', stolenness: 'non' } }
    let(:target_interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: nil) }
    context 'with per_page' do
      it 'returns matching bikes, defaults to stolen' do
        get '/api/v3/search/close_serials', query_params, format: :json
        result = JSON.parse(response.body)
        expect(result['bikes'][0]['id']).to eq bike.id
        expect(response.header['Total']).to eq('1')
      end
    end
  end
  describe '/count' do
    context 'incorrect stolenness value' do
      it 'returns an error message' do
        get '/api/v3/search/count', stolenness: 'something else', format: :json
        result = JSON.parse(response.body)
        expect(result['error']).to match(/stolenness/i)
        expect(response.status).to eq(400)
      end
    end
    context 'correct params' do
      let(:request_query_params) do
        {
          serial: 's',
          manufacturer: manufacturer.id,
          color_ids: [color.id],
          location: 'Chicago, IL',
          distance: 10,
          stolenness: 'stolen'
        }
      end
      let(:proximity_query_params) { request_query_params.merge(stolenness: 'proximity') }
      let(:proximity_interpreted_params) { Bike.searchable_interpreted_params(proximity_query_params, ip: '') }
      # Use the interpreted params, because they come with proximity data - it's what we do in the API
      let(:stolen_interpreted_params) { proximity_interpreted_params.merge(stolenness: 'stolen') }
      let(:non_stolen_interpreted_params) { proximity_interpreted_params.merge(stolenness: 'non') }
      it 'calls Bike Search with the expected interpreted_params' do
        expect(Bike).to receive(:search).with(proximity_interpreted_params) { %w(1) }
        expect(Bike).to receive(:search).with(stolen_interpreted_params) { %w(1 2) }
        expect(Bike).to receive(:search).with(non_stolen_interpreted_params) { %w(1 2 3) }
        get '/api/v3/search/count', request_query_params, format: :json
        result = JSON.parse(response.body)
        # The result is counts of the arrays we stubbed :/
        expect(result).to eq({ non: 3, stolen: 2, proximity: 1 }.as_json)
        expect(response.status).to eq(200)
      end
    end
    context 'nil params' do
      it 'succeeds' do
        get '/api/v3/search/count', { stolenness: '', query_items: [], serial: '' }, format: :json
        # JSON.parse(response.body)
        expect(response.status).to eq(200)
      end
    end
    context 'with query items' do
      let!(:bike) { FactoryGirl.create(:bike, manufacturer: manufacturer) }
      let!(:bike_2) { FactoryGirl.create(:bike) }
      let(:query_params) { { query_items: [manufacturer.search_id] } }
      it 'succeeds' do
        get '/api/v3/search/count', query_params, format: :json
        result = JSON.parse(response.body)
        expect(result['non']).to eq 1
        expect(response.status).to eq(200)
      end
    end
  end
end
