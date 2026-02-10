# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# NOTE: this does not seed manufacturers or primary_activities, those are pulled via rake task
require File.expand_path("db/seeds/seed_wheel_sizes", Rails.root)
require File.expand_path("db/seeds/seed_bike_associations", Rails.root)
require File.expand_path("db/seeds/seed_components", Rails.root)
require File.expand_path("db/seeds/seed_countries_and_states", Rails.root)
require File.expand_path("db/seeds/seed_organization", Rails.root)
require File.expand_path("db/seeds/seed_test_users_and_bikes", Rails.root)
require File.expand_path("db/seeds/seed_parking_notifications", Rails.root)
require File.expand_path("db/seeds/seed_stolen_and_found_bikes", Rails.root)
require File.expand_path("db/seeds/seed_counts", Rails.root)
