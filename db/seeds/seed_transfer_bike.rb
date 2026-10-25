# Seed one registered bike for transfer_provider@bikeindex.org, so an
# account-transfer demo has a bike to move.
#
# Idempotent, keyed on the owner: sandbox/review databases are long-lived and
# only seed on first boot, so bin/docker-entrypoint re-runs this every deploy
# to (re)create the bike on databases that already exist.

require File.expand_path("db/seeds/seed_helpers", Rails.root)

owner = User.find_by_email("transfer_provider@bikeindex.org")
return unless owner
return if owner.bikes.unscoped.exists?

SeedHelpers.with_clock do
  params = {
    bike: {
      cycle_type: "bike",
      propulsion_type: "foot-pedal",
      serial_number: (0...10).map { rand(65..90).chr }.join,
      manufacturer_id: Manufacturer.frame_makers.sample.id,
      primary_frame_color_id: Color.pluck(:id).sample,
      rear_tire_narrow: "true",
      handlebar_type: HandlebarType.slugs.first,
      owner_email: owner.email,
      description: "Seeded for the account transfer demo"
    }
  }
  b_param = BParam.create!(creator: owner, params:)
  bike = BikeServices::Creator.new.create_bike(b_param)
  raise b_param.bike_errors.to_s if bike.errors.any?

  puts "Created transfer demo bike ##{bike.id} for #{owner.email}"
end
