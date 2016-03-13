class CacheAllStolenWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'carrierwave', backtrace: true, retry: false
  attr_reader :filename

  def perform
    write_stolen
    uploader = JsonUploader.new
    file = File.open(tmp_path)
    uploader.store!(file)
    file.close
    FileCacheMaintainer.update_file_info(output_url(uploader))
  end

  def output_url(uploader)
    # If we're in fog, we need to open via a URL
    (JsonUploader.storage.to_s =~ /fog/i) ? uploader.url : uploader.current_path
  end

  def file_prefix
    Rails.env.test? ? '/spec/fixtures/tsv_creation/' : ''
  end

  def filename
    @filename ||= "#{file_prefix}#{Time.now.to_i}_all_stolen_cache.json"
  end

  def tmp_path
    File.join(Rails.root, filename)
  end

  def write_stolen
    File.open(tmp_path, 'w') {}
    File.open(tmp_path, 'a+') do |file|
      file << '{"bikes": ['
      Bike.stolen.find_each { |bike| file << BikeV2Serializer.new(bike, root: false).to_json + ',' }
    end
    File.truncate(tmp_path, File.size(tmp_path) - 1) # remove final comma
    File.open(tmp_path, 'a+') { |file| file << ']}' }
  end
end
