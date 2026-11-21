# Seed one registered bike for ios_review@bikeindex.org, the App Store review account.
#
# Idempotent, keyed on the owner: bin/docker-entrypoint re-runs this every deploy.

require File.expand_path("db/seeds/seed_helpers", Rails.root)

owner = User.find_by_email("ios_review@bikeindex.org")
return if owner.nil? || owner.bikes.exists?

bike = SeedHelpers.seed_bike(
  creator: BikeServices::Creator.new, user: owner, label: "iOS review bike",
  params: {bike: SeedHelpers.bike_params(owner_email: owner.email, manufacturer_id: Manufacturer.friendly_find("Jamis")&.id).merge(
    year: 2024,
    frame_model: "Coda",
    frame_material_slug: "aluminum",
    primary_frame_color_id: Color.friendly_find("Black").id,
    description: "Jamis Coda hybrid commuter"
  )}
)
puts "Created iOS review bike ##{bike.id} for #{owner.email}" unless bike.errors.any?
