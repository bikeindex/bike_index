# Seed one registered bike for transfer_provider@bikeindex.org, so an
# account-transfer demo has a bike to move.
#
# Idempotent, keyed on the owner: sandbox/review databases are long-lived and
# only seed on first boot, so bin/docker-entrypoint re-runs this every deploy
# to (re)create the bike on databases that already exist.

require File.expand_path("db/seeds/seed_helpers", Rails.root)

owner = User.find_by_email("transfer_provider@bikeindex.org")
return if owner.nil? || owner.bikes.exists?

bike = SeedHelpers.seed_bike(
  creator: BikeServices::Creator.new, user: owner, label: "Transfer demo bike",
  params: {bike: SeedHelpers.bike_params(owner_email: owner.email).merge(description: "Seeded for the account transfer demo")}
)
puts "Created transfer demo bike ##{bike.id} for #{owner.email}" unless bike.errors.any?
