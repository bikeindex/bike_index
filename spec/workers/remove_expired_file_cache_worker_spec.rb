require 'spec_helper'

describe RemoveExpiredFileCacheWorker do
  it { should be_processed_in :carrierwave }

  describe 'perform' do
    it 'removes expired files' do
      t = (Time.now - 3.days).to_i
      FileCacheMaintainer.reset_file_info("#{t}_all_stolen_cache.json", t)
      FileCacheMaintainer.update_file_info('current_stolen_bikes.tsv')
      expect(FileCacheMaintainer.files.count).to eq 2
      RemoveExpiredFileCacheWorker.new.perform
      expect(FileCacheMaintainer.files.count).to eq 1
      expect(FileCacheMaintainer.files.first['filename']).to eq 'current_stolen_bikes.tsv'
    end
  end
end
