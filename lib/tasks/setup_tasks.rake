namespace :setup do
  desc "Reset Autocomplete"
  task reset_autocomplete: :environment do
    AutocompleteLoaderJob.new.perform(nil, true)
  end

  desc "Load counts" # This is a rake task so it can be loaded from bin/update
  task load_counts: :environment do
    UpdateCountsJob.new.perform
  end

  desc "refresh reference data (manufacturers, primary activities, components) from bike_data GitHub spreadsheets"
  task import_spreadsheets: :environment do
    # Run inline rather than enqueue: seeding's later steps need this data present
    Spreadsheets::ImporterJob.new.perform
  end
end
