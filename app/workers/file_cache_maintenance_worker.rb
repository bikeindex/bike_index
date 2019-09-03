class FileCacheMaintenanceWorker < ScheduledWorker
  def self.frequency
    6.hours
  end

  def perform
    record_scheduler_started
    write_stolen
    uploader = JsonUploader.new
    file = File.open(tmp_path)
    uploader.store!(file)
    file.close
    FileCacheMaintainer.update_file_info(output_url(uploader))
    expired_file_hashes.each { |fh| FileCacheMaintainer.remove_file(fh) }
    record_scheduler_finished
  end

  def output_url(uploader)
    # If we're in fog, we need to open via a URL
    (JsonUploader.storage.to_s =~ /fog/i) ? uploader.url : uploader.current_path
  end

  def file_prefix
    Rails.env.test? ? "/spec/fixtures/tsv_creation/" : ""
  end

  def filename
    @filename ||= "#{file_prefix}#{Time.current.to_i}_all_stolen_cache.json"
  end

  def tmp_path
    File.join(Rails.root, filename)
  end

  def write_stolen
    File.open(tmp_path, "w") { }
    File.open(tmp_path, "a+") do |file|
      file << '{"bikes": ['
      Bike.stolen.find_each { |bike| file << BikeV2Serializer.new(bike, root: false).to_json + "," }
    end
    File.truncate(tmp_path, File.size(tmp_path) - 1) # remove final comma
    File.open(tmp_path, "a+") { |file| file << "]}" }
  end

  def expired_file_hashes
    expiration = (Time.current - 2.days).to_i
    FileCacheMaintainer.files.select do |file|
      file["updated_at"].to_i < expiration
    end
  end
end
