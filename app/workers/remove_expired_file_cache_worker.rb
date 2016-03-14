class RemoveExpiredFileCacheWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'carrierwave', backtrace: true, retry: false

  def perform
    expired_file_hashes.each { |fh| FileCacheMaintainer.remove_file(fh) }
  end

  def expired_file_hashes
    expiration = (Time.now - 2.days).to_i
    FileCacheMaintainer.files.select do |file|
      file['updated_at'].to_i < expiration
    end
  end
end
