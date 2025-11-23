task enqueue_newsletter: :environment do
  if Sidekiq.redis { |conn| conn.llen("queue:low_priority") < 3_000 }
    Email::NewsletterJob.enqueue_for(94, limit: 5_000)
  end
end

task run_scheduler: :environment do
  ScheduledJobRunner.perform_async if ScheduledJobRunner.should_enqueue?
end

task read_logged_searches: :environment do
  # Throw an error if ripgrep isn't installed
  abort("ripgrep (rg) is not installed") unless system("rg --version > /dev/null 2>&1")

  LogSearcher::Reader.write_log_lines(Time.current)
  LogSearcher::Reader.write_log_lines(Time.current - 1.hour)
end

desc "Reset Autocomplete"
task reset_autocomplete: :environment do
  AutocompleteLoaderJob.new.perform(nil, true)
end

desc "import manufacturers from GitHub"
task import_manufacturers_csv: :environment do
  url = "https://raw.githubusercontent.com/bikeindex/resources/refs/heads/main/manufacturers.csv"
  file_path = Rails.root.join("tmp/manufacturers.csv")
  system("wget -q #{url} -O #{file_path}", exception: true)
  Spreadsheets::Manufacturers.import(file_path)
end

desc "import primary activities from GitHub"
# NOTE: This doesn't actually do a good job updating existing primary activities.
# If that is required, probably do it manually via console
task import_primary_activities_csv: :environment do
  url = "https://raw.githubusercontent.com/bikeindex/resources/refs/heads/main/primary_activities.csv"
  file_path = Rails.root.join("tmp/primary_activities.csv")
  system("wget -q #{url} -O #{file_path}", exception: true)
  Spreadsheets::PrimaryActivities.import(file_path)
end

# TODO: Remove :processed attribute when processing finishes
desc "Enqueue Logged Search Processing"
task process_logged_searches: :environment do
  enqueue_limit = ENV["LOGGED_SEARCHES_BACKFILL_COUNT"]
  enqueue_limit = enqueue_limit.present? ? enqueue_limit.to_i : 1000

  LoggedSearch.unprocessed.limit(enqueue_limit).pluck(:id)
    .each { |i| ProcessLoggedSearchJob.perform_async(i) }
end

desc "Load counts" # This is a rake task so it can be loaded from bin/update
task load_counts: :environment do
  UpdateCountsJob.new.perform
end

desc "Prepare translations for committing to main"
task prepare_translations: :environment do
  require "i18n/tasks/cli"
  i18n_tasks = I18n::Tasks::CLI.new
  i18n_tasks.start(["normalize"])
  i18n_tasks.start(["health"])

  # Export JS translations to public/javascripts/translations.js
  I18n::JS.export
end

task exchange_rates_update: :environment do
  print "\nUpdating exchange rates..."
  is_success = ExchangeRateUpdator.update
  print is_success ? "done.\n" : "failed.\n"
end

task database_size: :environment do
  database_name = ActiveRecord::Base.connection.instance_variable_get(:@config)[:database]
  sql = "SELECT pg_size_pretty(pg_database_size('#{database_name}'));"

  # Get table sizes, sorted by their size
  tables_sql = "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
  tables = ActiveRecord::Base.connection.execute(tables_sql)
  output_tables = tables.map { |table|
    name = table["tablename"]
    pretty_size = ActiveRecord::Base.connection.execute("SELECT pg_size_pretty(pg_total_relation_size('#{name}'));")
    size = ActiveRecord::Base.connection.execute("SELECT pg_total_relation_size('#{name}');")
    {
      name: name,
      size: size[0]["pg_total_relation_size"],
      pretty_size: pretty_size[0]["pg_size_pretty"]
    }
  }.sort_by { |a| a[:size] }

  # Get the width the name column needs to be
  name_col_length = output_tables.map { |t| t[:name].length }.max + 3

  # Print the
  output_tables.each do |table|
    puts "#{table[:name].ljust(name_col_length)} | #{table[:pretty_size]}"
  end

  # Print DB size
  puts "\n#{"Total size".ljust(name_col_length)} | #{ActiveRecord::Base.connection.execute(sql)[0]["pg_size_pretty"]}"
end

desc "Migrate RecoveryDisplay images from CarrierWave to ActiveStorage"
task migrate_recovery_display_images: :environment do
  recovery_display_ids = RecoveryDisplay.where.not(image: [nil, ""])
    .where.missing(:photo_attachment)
    .pluck(:id)

  puts "Enqueueing migration for #{recovery_display_ids.count} recovery displays"
  recovery_display_ids.each do |id|
    RecoveryDisplayMigrateImageJob.perform_async(id)
  end
  puts "Done!"
end

desc "Provide DB vacuum for production environment"
task database_vacuum: :environment do
  tables = ActiveRecord::Base.connection.tables
  tables.each do |table|
    ActiveRecord::Base.connection.execute("VACUUM FULL ANALYZE #{table};")
  end
rescue
  Rails.logger.error("Database VACUUM error: #{exc.message}")
end
