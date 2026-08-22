# Abort loudly if the import fails: later steps (e.g. seed_manufacturer_priorities)
# depend on this reference data and would otherwise raise a misleading error.
abort "Seeding failed: bin/rake setup:import_spreadsheets" unless system("bin/rake setup:import_spreadsheets")

# Seeds that send mail render layouts/email, which links a dartsass-built stylesheet -
# Sprockets raises on a missing one rather than skipping the tag
unless Rails.application.config.dartsass.builds.values.all? { Rails.root.join("app/assets/builds", it).exist? }
  puts "\n== Building stylesheets =="
  Rake::Task["dartsass:build"].invoke
end

# Set Cgroup display order; the import assigns priority by CSV row order, which isn't what we want
cgroup_priorities = [["Frame and Fork", 1], ["Wheels", 2], ["Drivetrain", 3], ["Brakes", 4], ["Cargo", 5], ["Additional Parts", 6]]
cgroup_priorities.each do |name, priority|
  cgroup = Cgroup.friendly_find(name) || raise("Cgroup not found: #{name}")
  cgroup.update!(priority:)
end

# NOTE: this does not seed manufacturers, primary_activities or components, those are pulled via rake task
require File.expand_path("db/seeds/seed_helpers", Rails.root)
require File.expand_path("db/seeds/seed_wheel_sizes", Rails.root)
require File.expand_path("db/seeds/seed_bike_associations", Rails.root)
require File.expand_path("db/seeds/seed_countries_and_states", Rails.root)
require File.expand_path("db/seeds/seed_test_users", Rails.root)
require File.expand_path("db/seeds/seed_info_blogs", Rails.root)
require File.expand_path("db/seeds/seed_organizations", Rails.root)
require File.expand_path("db/seeds/seed_manufacturer_priorities", Rails.root)
require File.expand_path("db/seeds/seed_bikes", Rails.root)
require File.expand_path("db/seeds/seed_marketplace_listings", Rails.root)
require File.expand_path("db/seeds/seed_organization_bikes_and_associations", Rails.root)
require File.expand_path("db/seeds/seed_organized_emails", Rails.root)
require File.expand_path("db/seeds/seed_registration_sequence_template", Rails.root)
require File.expand_path("db/seeds/seed_counts", Rails.root)
require File.expand_path("db/seeds/seed_oauth_app", Rails.root)

# Load the search autocomplete (Redis) from the seeded manufacturers/colors/etc.
# so it matches the database. Without this, a freshly seeded app (e.g. a review
# app on first boot) has manufacturers in the DB but an empty autocomplete, which
# makes ScheduledAutocompleteCheckJob raise "Missing Manufacturers!".
AutocompleteLoaderJob.new.perform(nil, true)
