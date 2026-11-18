# Creates a single deterministic bike for ios_review@bikeindex.org.
#
# MainContentUITest only needs "at least one bike" on the grid; ScreenshotUITest
# uses user@fakegmail.com. We deliberately avoid a Riese & Müller (user@ already
# owns one, and duplicate imagery would be confusing in screenshot comparisons).
#
# 2024 Giant Escape (3) — common city hybrid, distinct from all other test labels.

owner = User.find_by_email("ios_review@bikeindex.org")
raise "ios_review user not found" unless owner

puts "Seeding 2024 Giant Escape (3) for ios_review@bikeindex.org..."

creator = BikeServices::Creator.new

# Use the same color as the test expects — "black" is consistent across environments.
black_id = Color.friendly_find("black")&.id || Color.first&.id

bike = SeedHelpers.seed_bike(
  creator:,
  user: owner,
  params: {bike: SeedHelpers.bike_params(owner_email: owner.email).merge(
    year: 2024,
    manufacturer_id: Manufacturer.friendly_find("Giant").id,
    frame_model: "Escape (3)",
    frame_material_slug: "aluminum",
    cycle_type: "hybrid",
    primary_frame_color_id: black_id,
    handlebar_type: "flat",
    description: "Giant Escape 3 hybrid commuter. 2024 model."
  )},
  origin: "organization_form",
  label: "2024 Giant Escape (3)"
)

raise "Failed to create bike: #{bike.errors.full_messages.join(", ")}" if bike.errors.any?

bike.current_ownership.mark_claimed

puts "  Created 2024 Giant Escape (3) for ios_review@bikeindex.org"
