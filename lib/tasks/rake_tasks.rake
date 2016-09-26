task :slow_save => :environment do
  User.find_in_batches(batch_size: 500) do |b|
    b.each { |i| i.save }
  end

  # Bike.where("thumb_path IS NOT NULL").find_in_batches(batch_size: 150) do |b|
  #   b.each { |i| AfterBikeSaveWorker.perform_async(i.id) }
  #   sleep(50)
  # end
end

task delete_expired_b_params: :environment do
  BParam.pluck(:id).each { |id| RemoveExpiredBParamsWorker.perform_async(id) }
end

desc 'Create frame_makers and push to redis'
task :sm_import_manufacturers => :environment do
  AutocompleteLoaderWorker.perform_async('load_manufacturers')
end

desc 'Create frame_makers and push to redis'
task :remove_unused_ownerships => :environment do
  Ownership.pluck(:id).each { |id| UnusedOwnershipRemovalWorker.perform_async(id) }
end

desc 'cache all stolen response'
task :cache_all_stolen => :environment do
  CacheAllStolenWorker.perform_async
end

desc 'Remove expired file caches'
task :remove_expired_file_caches => :environment do
  RemoveExpiredFileCacheWorker.perform_async
end

desc 'remove unused'
task :cache_all_stolen => :environment do
  CacheAllStolenWorker.perform_async
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


desc 'create creation states'
task :create_creation_states => :environment do
  Bike.find_each do |b|
    creation_state = CreationState.where(bike_id: b.id).first_or_create
    creation_state.is_new ||= bike.registered_new
    creation_state.update_attributes(creator_id: b.creator_id, organization_id: b.creation_organization_id)
  end
end