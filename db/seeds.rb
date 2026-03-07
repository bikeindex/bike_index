system "bin/rake setup:import_manufacturers_csv setup:import_primary_activities_csv"

# NOTE: this does not seed manufacturers or primary_activities, those are pulled via rake task
require File.expand_path("db/seeds/seed_wheel_sizes", Rails.root)
require File.expand_path("db/seeds/seed_bike_associations", Rails.root)
require File.expand_path("db/seeds/seed_components", Rails.root)
require File.expand_path("db/seeds/seed_countries_and_states", Rails.root)
require File.expand_path("db/seeds/seed_test_users", Rails.root)
require File.expand_path("db/seeds/seed_organizations", Rails.root)
require File.expand_path("db/seeds/seed_bikes", Rails.root)
require File.expand_path("db/seeds/seed_parking_notifications_and_impound_records", Rails.root)
require File.expand_path("db/seeds/seed_counts", Rails.root)
