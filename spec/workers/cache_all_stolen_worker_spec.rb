require 'spec_helper'

describe CacheAllStolenWorker do
  it { should be_processed_in :carrierwave }

  describe 'output_stolen' do
    it 'creates a stolen cache' do
      FactoryGirl.create(:stolen_bike)
      TsvMaintainer.redis.expire(TsvMaintainer.info_id, 0)
      CacheAllStolenWorker.new.perform
      tsv_record = TsvMaintainer.tsvs.last
      expect(tsv_record['filename']).to match 'all_stolen_cache.json'
    end
  end

  describe 'write_stolen' do
    it 'outputs the correct stolen' do
      FactoryGirl.create(:stolen_bike, serial_number: 'party seri8al')
      cache_all_stolen_worker = CacheAllStolenWorker.new
      cache_all_stolen_worker.write_stolen
      result = JSON.parse(File.read(cache_all_stolen_worker.tmp_path))
      expect(result['bikes'].count).to eq(1)
      expect(result['bikes'][0]['serial']).to eq('party seri8al')
      bike_v2_serializer_keys = %w(id title serial manufacturer_name frame_model year frame_colors thumb large_img is_stock_img stolen stolen_location date_stolen)
      expect(result['bikes'][0].keys).to eq bike_v2_serializer_keys
    end
  end
end
