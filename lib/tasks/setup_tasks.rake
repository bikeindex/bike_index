namespace :setup do
  desc "Reset Autocomplete"
  task reset_autocomplete: :environment do
    AutocompleteLoaderJob.new.perform(nil, true)
  end

  desc "Load counts" # This is a rake task so it can be loaded from bin/update
  task load_counts: :environment do
    UpdateCountsJob.new.perform
  end

  desc "refresh reference data (manufacturers, primary activities, components) from spreadsheets"
  task import_spreadsheets: :environment do
    Spreadsheets::ImporterJob.new.perform
  end
end
