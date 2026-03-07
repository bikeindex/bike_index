namespace :setup do
  desc "Reset Autocomplete"
  task reset_autocomplete: :environment do
    AutocompleteLoaderJob.new.perform(nil, true)
  end

  desc "Load counts" # This is a rake task so it can be loaded from bin/update
  task load_counts: :environment do
    UpdateCountsJob.new.perform
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
end
