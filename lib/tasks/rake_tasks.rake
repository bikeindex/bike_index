task :start do
  system 'redis-server &'
  system 'bundle exec foreman start -f Procfile_development'
end

desc "Create frame_makers and push to redis"
task :sm_import_manufacturers => :environment do
  SmImportWorker.perform_async
end

desc "Create frame_makers and push to redis"
task :remove_unused_ownerships => :environment do
  Ownership.pluck(:id).each { |id| UnusedOwnershipRemovalWorker.perform_async(id) }
end

desc "Create stolen tsv"
task :create_tsvs => :environment do
  TsvCreatorWorker.perform_async('create_manufacturer')
  TsvCreatorWorker.perform_async('create_stolen_with_reports')
  TsvCreatorWorker.perform_in(1.hour, 'create_stolen')
end

desc "download manufacturer logos" 
task :download_manufacturer_logos => :environment do
  Manufacturer.with_websites.pluck(:id).each_with_index do |id, index|
    GetManufacturerLogoWorker.perform_in((5*index).seconds, id)
  end
end