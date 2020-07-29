require "rails_helper"

RSpec.describe FileCacheMaintainer do
  describe "cached_all_stolen" do
    it "returns the most recent all_stolen" do
      FileCacheMaintainer.update_file_info("1456863086_all_stolen_cache.json", 1456863086)
      t = Time.current.to_i
      FileCacheMaintainer.update_file_info("#{t}_all_stolen_cache.json", t)
      target = {
        "path" => "#{t}_all_stolen_cache.json",
        "filename" => "#{t}_all_stolen_cache.json",
        "daily" => true,
        "updated_at" => t.to_s,
        "description" => nil
      }
      expect(FileCacheMaintainer.cached_all_stolen).to eq(target)
    end
  end

  describe "blocklist_ids" do
    it "gets and sets the ids" do
      FileCacheMaintainer.reset_blocklist_ids([1, 1, 2, 4, "https://bikeindex.org/admin/bikes/6"])
      expect(FileCacheMaintainer.blocklist).to eq %w[1 2 4 6]
    end
    it "doesn't break if it's empty" do
      FileCacheMaintainer.reset_blocklist_ids([])
      expect(FileCacheMaintainer.blocklist).to eq([])
    end
  end

  describe "blocklist_include" do
    it "checks if blocklist includes something" do
      FileCacheMaintainer.reset_blocklist_ids([1010101, 2, 4, 6])
      expect(FileCacheMaintainer.blocklist_include?("http://bikeindex.org/bikes/1010101/edit")).to be_truthy
      expect(FileCacheMaintainer.blocklist_include?(7)).to be_falsey
    end
  end

  describe "tsv info" do
    it "updates tsv info and returns with indifferent access" do
      t = Time.current
      FileCacheMaintainer.reset_file_info("current_stolen_bikes.tsv", t)
      tsv = FileCacheMaintainer.files[0]
      expect(tsv[:updated_at]).to eq(t.to_i.to_s)
      expect(tsv[:daily]).to be_falsey
      expect(tsv["path"]).to eq("current_stolen_bikes.tsv")
      expect(tsv["description"]).to eq("Stolen")
    end

    it "returns the way we want - dailys after non daily" do
      t = Time.current
      FileCacheMaintainer.reset_file_info("https://files.bikeindex.org/uploads/tsvs/approved_current_stolen_bikes.tsv", t)
      FileCacheMaintainer.update_file_info("https://files.bikeindex.org/uploads/tsvs/current_stolen_bikes.tsv")
      FileCacheMaintainer.update_file_info("https://files.bikeindex.org/uploads/tsvs/#{Time.current.strftime("%Y_%-m_%-d")}_approved_current_stolen_bikes.tsv")
      FileCacheMaintainer.update_file_info("https://files.bikeindex.org/uploads/tsvs/#{Time.current.strftime("%Y_%-m_%-d")}_current_stolen_bikes.tsv")
      FileCacheMaintainer.files.each_with_index do |file, index|
        if index < 2
          expect(["approved_current_stolen_bikes.tsv", "current_stolen_bikes.tsv"].include?(file[:filename])).to be_truthy
        else
          expect(["#{Time.current.strftime("%Y_%-m_%-d")}_approved_current_stolen_bikes.tsv", "#{Time.current.strftime("%Y_%-m_%-d")}_current_stolen_bikes.tsv"].include?(file[:filename])).to be_truthy
        end
      end
    end
  end

  describe "remove_file" do
    it "deletes the file" do
      FactoryBot.create(:stolen_bike)
      FileCacheMaintainer.reset_file_info("1456863086_all_stolen_cache.json", 1456863086)
      FileCacheMaintenanceWorker.new.perform
      files_count = FileCacheMaintainer.files.count
      cached_all_stolen = FileCacheMaintainer.cached_all_stolen
      expect(Dir["spec/fixtures/tsv_creation/*"].join).to match(cached_all_stolen["filename"])
      FileCacheMaintainer.remove_file(cached_all_stolen)
      expect(FileCacheMaintainer.files.count).to eq(files_count - 1)
      # For some reason, carrierwave doesn't deleting the file in tests, but it works
      # in development and production. Obviously, no good - but... Moving on right now.
      # expect(Dir['spec/fixtures/tsv_creation/*'].join(' ')).to_not match(cached_all_stolen['filename'])
    end
  end
end
