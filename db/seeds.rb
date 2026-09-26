# Seeding isn't idempotent: a re-run over seeded records dies on duplicates
if Bike.unscoped.exists?
  puts "Database already seeded"
  return
end

# Development logs every query with its caller's backtrace, which is over a third of seeding
Rails.logger.level = :info
# Seeded users' passwords are published, so hashing them at the default cost buys nothing
ActiveModel::SecurePassword.min_cost = true

SpreadsheetJobs::ImporterJob.new.perform

# Set Cgroup display order; the import assigns priority by CSV row order, which isn't what we want
cgroup_priorities = [["Frame and Fork", 1], ["Wheels", 2], ["Drivetrain", 3], ["Brakes", 4], ["Cargo", 5], ["Additional Parts", 6]]
cgroup_priorities.each do |name, priority|
  cgroup = Cgroup.friendly_find(name) || raise("Cgroup not found: #{name}")
  cgroup.update!(priority:)
end

# NOTE: this does not seed manufacturers, primary_activities or components, those are pulled via rake task
require File.expand_path("db/seeds/seed_helpers", Rails.root)
SeedHelpers.with_clock do
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
  require File.expand_path("db/seeds/seed_oauth_app", Rails.root)
end
require File.expand_path("db/seeds/seed_counts", Rails.root)

# Load the search autocomplete (Redis) from the seeded manufacturers/colors/etc.
# so it matches the database. Without this, a freshly seeded app (e.g. a review
# app on first boot) has manufacturers in the DB but an empty autocomplete, which
# makes ScheduledAutocompleteCheckJob raise "Missing Manufacturers!".
AutocompleteLoaderJob.new.perform(nil, true)
