require 'spec_helper'

describe 'Bikes API V2' do
  describe 'bike search' do
    before :each do
      @bike = FactoryGirl.create(:bike)
      FactoryGirl.create(:bike)
      FactoryGirl.create(:recovered_bike)
    end
    it 'all bikes (root) search works' do
      get '/api/v2/bikes_search?per_page=1', format: :json
      expect(response.code).to eq('200')
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end

    it 'non_stolen bikes search works' do
      get '/api/v2/bikes_search/non_stolen?per_page=1', format: :json
      expect(response.code).to eq('200')
      expect(response.header['Total']).to eq('2')
      expect(response.header['Link'].match('page=2&per_page=1>; rel=\"next\"')).to be_present
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end

    it 'serial search works' do
      bike = FactoryGirl.create(:bike, serial_number: '0000HEYBB')
      get '/api/v2/bikes_search/?serial=0HEYBB', format: :json
      result = JSON.parse(response.body)
      expect(response.code).to eq('200')
      expect(response.header['Total']).to eq('1')
      expect(result['bikes'][0]['id']).to eq(bike.id)
    end

    it 'stolen search works' do
      bike = FactoryGirl.create(:stolen_bike)
      get '/api/v2/bikes_search/stolen?per_page=1', format: :json
      expect(response.code).to eq('200')
      expect(response.header['Total']).to eq('1')
      result = response.body
      expect(JSON.parse(result)['bikes'][0]['id']).to be_present
    end
  end

  describe 'fuzzy serial search' do
    it 'finds a close one' do
      bike = FactoryGirl.create(:bike, serial_number: 'Something1')
      bike.create_normalized_serial_segments
      get '/api/v2/bikes_search/close_serials?serial=s0meth1nglvv', format: :json
      result = JSON.parse(response.body)
      expect(response.code).to eq('200')
      expect(response.header['Total']).to eq('1')
      expect(result['bikes'][0]['id']).to eq(bike.id)
    end
  end

  describe 'count' do
    it "returns the count hash for matching bikes, doesn't need access_token" do
      bike = FactoryGirl.create(:bike, serial_number: 'awesome')
      FactoryGirl.create(:bike)
      get '/api/v2/bikes_search/count?query=awesome', format: :json
      result = JSON.parse(response.body)
      expect(result['non_stolen']).to eq(1)
      expect(result['stolen']).to eq(0)
      expect(result['proximity']).to eq(0)
      expect(response.code).to eq('200')
    end

    it 'proximity square does not overwrite the proximity_radius' do
      opts = { proximity_square: 100, proximity_radius: '10' }
      target = Hashie::Mash.new(opts.merge(proximity: 'ip'))
      expect_any_instance_of(BikeSearcher).to receive(:initialize).with(target)
      get '/api/v2/bikes_search/count', opts, format: :json
    end
  end

  describe 'all_stolen' do
    it 'returns the cached file' do
      FactoryGirl.create(:stolen_bike)
      t = Time.now.to_i
      CacheAllStolenWorker.new.perform
      cached_all_stolen = FileCacheMaintainer.cached_all_stolen
      expect(cached_all_stolen['updated_at'].to_i).to be >= t
      get '/api/v2/bikes_search/all_stolen', format: :json
      result = JSON.parse(response.body)
      expect(response.header['Last-Modified']).to eq Time.at(cached_all_stolen['updated_at'].to_i).httpdate
      expect(result).to eq(JSON.parse(File.read(cached_all_stolen['path'])))
    end
  end
end
