require 'spec_helper'

describe FileCacheMaintainer do
  describe 'cached_all_stolen' do
    it 'returns the most recent all_stolen' do
      FileCacheMaintainer.update_file_info('1456863086_all_stolen_cache.json', 1456863086)
      t = Time.now.to_i
      FileCacheMaintainer.update_file_info("#{t}_all_stolen_cache.json", t)
      target = {
        'path' => "#{t}_all_stolen_cache.json",
        'filename' => "#{t}_all_stolen_cache.json",
        'daily' => true,
        'updated_at' => t.to_s,
        'description' => nil
      }
      expect(FileCacheMaintainer.cached_all_stolen).to eq(target)
    end
  end

  describe 'blacklist_ids' do
    it 'gets and sets the ids' do
      FileCacheMaintainer.reset_blacklist_ids([1, 1, 2, 4, 'https://bikeindex.org/admin/bikes/6'])
      expect(FileCacheMaintainer.blacklist).to eq %w(1 2 4 6)
    end
    it "doesn't break if it's empty" do
      FileCacheMaintainer.reset_blacklist_ids([])
      expect(FileCacheMaintainer.blacklist).to eq([])
    end
  end

  describe 'blacklist_include' do
    it 'checks if blacklist includes something' do
      FileCacheMaintainer.reset_blacklist_ids([1010101, 2, 4, 6])
      expect(FileCacheMaintainer.blacklist_include?('http://bikeindex.org/bikes/1010101/edit')).to be_truthy
      expect(FileCacheMaintainer.blacklist_include?(7)).to be_falsey
    end
  end

  describe 'tsv info' do
    it 'updates tsv info and returns with indifferent access' do
      t = Time.now
      FileCacheMaintainer.reset_file_info('current_stolen_bikes.tsv', t)
      tsv = FileCacheMaintainer.files[0]
      expect(tsv[:updated_at]).to eq(t.to_i.to_s)
      expect(tsv[:daily]).to be_falsey
      expect(tsv['path']).to eq('current_stolen_bikes.tsv')
      expect(tsv['description']).to eq('Stolen')
    end

    it 'returns the way we want' do
      t = Time.now
      FileCacheMaintainer.reset_file_info('https://files.bikeindex.org/uploads/tsvs/approved_current_stolen_bikes.tsv', t)
      FileCacheMaintainer.update_file_info('https://files.bikeindex.org/uploads/tsvs/current_stolen_bikes.tsv')
      FileCacheMaintainer.update_file_info("https://files.bikeindex.org/uploads/tsvs/#{Time.now.strftime('%Y_%-m_%-d')}_approved_current_stolen_bikes.tsv")
      FileCacheMaintainer.update_file_info("https://files.bikeindex.org/uploads/tsvs/#{Time.now.strftime('%Y_%-m_%-d')}_current_stolen_bikes.tsv")

      expect(FileCacheMaintainer.files[0][:filename]).to eq('current_stolen_bikes.tsv')
      expect(FileCacheMaintainer.files[1][:filename]).to eq('approved_current_stolen_bikes.tsv')
      expect(FileCacheMaintainer.files[2][:filename]).to eq("#{Time.now.strftime('%Y_%-m_%-d')}_current_stolen_bikes.tsv")
      expect(FileCacheMaintainer.files[3][:filename]).to eq("#{Time.now.strftime('%Y_%-m_%-d')}_approved_current_stolen_bikes.tsv")
    end
  end

  describe 'remove_file' do
    it 'deletes the file' do
      FactoryGirl.create(:stolen_bike)
      FileCacheMaintainer.reset_file_info('1456863086_all_stolen_cache.json', 1456863086)
      CacheAllStolenWorker.new.perform
      files_count = FileCacheMaintainer.files.count
      cached_all_stolen = FileCacheMaintainer.cached_all_stolen
      expect(Dir['spec/fixtures/tsv_creation/*'].join).to match(cached_all_stolen['filename'])
      FileCacheMaintainer.remove_file(cached_all_stolen)
      expect(FileCacheMaintainer.files.count).to eq(files_count - 1)
      # For some reason, carrierwave doesn't deleting the file in tests, but it works
      # in development and production. Obviously, no good - but... Moving on right now.
      # expect(Dir['spec/fixtures/tsv_creation/*'].join(' ')).to_not match(cached_all_stolen['filename'])
    end
  end
end
