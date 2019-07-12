task run_scheduler: :environment do
  ScheduledWorkerRunner.perform_async if ScheduledWorkerRunner.should_enqueue?
end

task :slow_save => :environment do
  User.find_in_batches(batch_size: 500) do |b|
    b.each { |i| i.save }
  end

  # Bike.where("thumb_path IS NOT NULL").find_in_batches(batch_size: 150) do |b|
  #   b.each { |i| AfterBikeSaveWorker.perform_async(i.id) }
  #   sleep(50)
  # end
end

desc "Create frame_makers and push to redis"
task :sm_import_manufacturers => :environment do
  AutocompleteLoaderWorker.perform_async("load_manufacturers")
end
