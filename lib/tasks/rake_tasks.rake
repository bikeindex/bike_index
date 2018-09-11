task :slow_save => :environment do
  User.find_in_batches(batch_size: 500) do |b|
    b.each { |i| i.save }
  end

  # Bike.where("thumb_path IS NOT NULL").find_in_batches(batch_size: 150) do |b|
  #   b.each { |i| AfterBikeSaveWorker.perform_async(i.id) }
  #   sleep(50)
  # end
end

desc 'Create frame_makers and push to redis'
task :sm_import_manufacturers => :environment do
  AutocompleteLoaderWorker.perform_async('load_manufacturers')
end

desc 'cache all stolen response'
task :cache_all_stolen => :environment do
  CacheAllStolenWorker.perform_async
end

desc "Daily maintenance tasks to be run"
task :daily_maintenance_tasks => :environment do
  RemoveExpiredFileCacheWorker.perform_async
  Invoice.where(subscription_end_at: (Time.now - 25.hours)..(Time.now + 25.hours))
         .each { |i| Invoice.update_attributes(updated_at: Time.now) }
  Ownership.pluck(:id).each { |id| UnusedOwnershipRemovalWorker.perform_async(id) }
end

desc 'Create stolen tsv'
task :create_tsvs => :environment do
  TsvCreator.enqueue_creation
end

desc 'download manufacturer logos' 
task :download_manufacturer_logos => :environment do
  Manufacturer.with_websites.pluck(:id).each_with_index do |id, index|
    GetManufacturerLogoWorker.perform_in((5*index).seconds, id)
  end
end
