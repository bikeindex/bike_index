system "bin/rake setup:import_spreadsheets"

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

# Load the search autocomplete (Redis) from the seeded manufacturers/colors/etc.
# so it matches the database. Without this, a freshly seeded app (e.g. a review
# app on first boot) has manufacturers in the DB but an empty autocomplete, which
# makes ScheduledAutocompleteCheckJob raise "Missing Manufacturers!".
AutocompleteLoaderJob.new.perform(nil, true)
