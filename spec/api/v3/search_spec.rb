require 'spec_helper'

describe 'Search API V3' do
  # For the time being, only count is implemented
  let(:manufacturer) { FactoryGirl.create(:manufacturer) }
  let(:color) { FactoryGirl.create(:color) }
  describe 'count' do
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
        result = JSON.parse(response.body)
        expect(response.status).to eq(200)
      end
    end
  end
end
