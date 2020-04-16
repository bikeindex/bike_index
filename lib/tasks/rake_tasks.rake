task run_scheduler: :environment do
  ScheduledWorkerRunner.perform_async if ScheduledWorkerRunner.should_enqueue?
end

task slow_save: :environment do
  User.find_in_batches(batch_size: 500) do |b|
    b.each { |i| i.save }
  end

  # Bike.where("thumb_path IS NOT NULL").find_in_batches(batch_size: 150) do |b|
  #   b.each { |i| AfterBikeSaveWorker.perform_async(i.id) }
  #   sleep(50)
  # end
end

desc "Create frame_makers and push to redis"
task sm_import_manufacturers: :environment do
  AutocompleteLoaderWorker.perform_async("load_manufacturers")
end

desc "Prepare translations for committing to master"
task prepare_translations: :environment do
  require "i18n/tasks/cli"
  i18n_tasks = I18n::Tasks::CLI.new
  i18n_tasks.start(["normalize"])
  i18n_tasks.start(["health"])

  # Export JS translations to public/javascripts/translations.js
  I18n::JS.export
end

task database_size: :environment do
  database_name = ActiveRecord::Base.connection.instance_variable_get("@config")[:database]
  sql = "SELECT pg_size_pretty(pg_database_size('#{database_name}'));"

  # Get table sizes, sorted by their size
  tables_sql = "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
  tables = ActiveRecord::Base.connection.execute(tables_sql)
  output_tables = tables.map do |table|
    name = table['tablename']
    pretty_size = ActiveRecord::Base.connection.execute("SELECT pg_size_pretty(pg_total_relation_size('#{name}'));")
    size = ActiveRecord::Base.connection.execute("SELECT pg_total_relation_size('#{name}');")
    {
      name: name,
      size: size[0]["pg_total_relation_size"],
      pretty_size: pretty_size[0]["pg_size_pretty"],
    }
  end.sort { |x, y| y[:size] <=> x[:size] }

  # Get the width the name column needs to be
  name_col_length = output_tables.map { |t| t[:name].length }.max + 3

  # Print the
  output_tables.each do |table|
    puts "#{table[:name].ljust(name_col_length)} | #{table[:pretty_size]}"
  end

  # Print DB size
  puts "\n#{'Total size'.ljust(name_col_length) } | #{ActiveRecord::Base.connection.execute(sql)[0]["pg_size_pretty"]}"
end
