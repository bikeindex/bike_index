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
  TsvCreatorWorker.perform_async('create_stolen')
  TsvCreatorWorker.perform_async('create_stolen_with_reports')
end
