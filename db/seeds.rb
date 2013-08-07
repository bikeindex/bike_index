# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

require File.expand_path('db/seeds/seed_manufacturers', Rails.root)
require File.expand_path('db/seeds/seed_wheel_sizes', Rails.root)
require File.expand_path('db/seeds/seed_bike_associations', Rails.root)
require File.expand_path('db/seeds/seed_components', Rails.root)

# We have a silly random string at the top of a few pages.
# They will break unless there is a value there... So here one is
flavor = FlavorText.create(message: "Bike like the wind")
flavor.save