require "rails_helper"

RSpec.describe FileCacheMaintenanceWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
    expect(described_class.frequency).to be > 5.hours
  end

  describe "output_stolen" do
    it "creates a stolen cache" do
      FactoryBot.create(:stolen_bike)
      FileCacheMaintainer.redis.expire(FileCacheMaintainer.info_id, 0)
      described_class.new.perform
      tsv_record = FileCacheMaintainer.files.last
      expect(tsv_record["filename"]).to match "all_stolen_cache.json"
    end
  end

  describe "write_stolen" do
    it "outputs the correct stolen" do
      FactoryBot.create(:stolen_bike, serial_number: "party seri8al")
      cache_all_stolen_worker = described_class.new
      cache_all_stolen_worker.write_stolen
      result = JSON.parse(File.read(cache_all_stolen_worker.tmp_path))
      expect(result["bikes"].count).to eq(1)
      expect(result["bikes"][0]["serial"]).to eq("party seri8al")
      expect(result["bikes"][0].keys).to(match_array <<~KEYS.split)
        id title serial manufacturer_name frame_model year frame_colors
        thumb large_img is_stock_img stolen stolen_location date_stolen
        date_stolen_string info_hash description location_found external_id
        registry_name registry_url source_name source_unique_id status url
      KEYS
    end
  end

  describe "removing expired files" do
    it "removes expired files" do
      t = (Time.current - 3.days).to_i
      expired_filename = "#{t}_all_stolen_cache.json"
      FileCacheMaintainer.reset_file_info(expired_filename, t)
      FileCacheMaintainer.update_file_info("current_stolen_bikes.tsv")
      expect(FileCacheMaintainer.files.count).to eq 2
      expect(FileCacheMaintainer.files.map { |f| f["filename"] }.include?(expired_filename)).to be_truthy
      described_class.new.perform
      expect(FileCacheMaintainer.files.map { |f| f["filename"] }.include?(expired_filename)).to be_falsey
    end
  end
end
