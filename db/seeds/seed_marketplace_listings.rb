# Seed marketplace listings for the marketplace index.
# "Promoted" listings are those whose seller has an active membership -
# they're partitioned to the top of /search/marketplace under a "Promoted" header.
admin = User.find_by_email("admin@bikeindex.org")
creator = BikeServices::Creator.new
primary_activity_ids = PrimaryActivity.where(family: false).pluck(:id)

listing_locations = [
  {street: "One Shields Ave", city: "Davis", postal_code: "95616", latitude: 38.5449065, longitude: -121.7405167, region_record: State.find_by_abbreviation("CA")},
  {street: "1300 W 14th Pl", city: "Chicago", postal_code: "60608", latitude: 41.8624488, longitude: -87.6591502, region_record: State.find_by_abbreviation("IL")},
  {street: "100 W 1st St", city: "Los Angeles", postal_code: "90012", latitude: 34.05223, longitude: -118.24368, region_record: State.find_by_abbreviation("CA")},
  {street: "55 Water St", city: "New York", postal_code: "10041", latitude: 40.7035731, longitude: -74.0093871, region_record: State.find_by_abbreviation("NY")}
].map { |location| location.merge(kind: :marketplace_listing, country: Country.united_states, skip_geocoding: true) }

def seed_marketplace_seller(email:, name:)
  user = User.create!(name:, email:, password: "pleaseplease12",
    password_confirmation: "pleaseplease12", terms_of_service: true)
  user.confirm(user.confirmation_token)
  user
end

def seed_marketplace_bike(creator:, seller:, manufacturer_id:, primary_activity_id:)
  b_param = BParam.create!(creator: seller, params: {bike: {
    cycle_type: "bike", propulsion_type: "foot-pedal", manufacturer_id:, primary_activity_id:,
    serial_number: (0...10).map { rand(65..90).chr }.join,
    primary_frame_color_id: Color.pluck(:id).sample,
    rear_tire_narrow: [true, false].sample, handlebar_type: HandlebarType.slugs.sample,
    owner_email: seller.email
  }})
  bike = creator.create_bike(b_param)
  raise "Marketplace bike error: #{b_param.bike_errors}" if bike.errors.any?
  bike
end

def seed_marketplace_listing(bike:, seller:, location:, amount_cents:, condition:)
  address_record = AddressRecord.new(location.merge(user: seller, bike:))
  MarketplaceListing.create!(item: bike, seller:, status: :for_sale,
    condition:, amount_cents:, address_record:)
end

conditions = MarketplaceListing::CONDITION_ENUM.keys

# --- 6 standard listings + 4 promoted (seller has an active membership) ---
listings = 10.times.map do |i|
  promoted = i >= 6
  prefix = promoted ? "member" : "seller"
  seller = seed_marketplace_seller(email: "marketplace-#{prefix}-#{i}@bikeindex.org", name: "Marketplace #{prefix.capitalize} #{i + 1}")
  Membership.create!(user: seller, creator: admin, level: :basic, start_at: Time.current - 1.hour) if promoted
  bike = seed_marketplace_bike(creator:, seller:, manufacturer_id: SeedHelpers.weighted_frame_maker_id, primary_activity_id: primary_activity_ids.sample)
  seed_marketplace_listing(bike:, seller:, location: listing_locations[i % listing_locations.length],
    amount_cents: (250 + i * 175) * 100, condition: conditions[i % conditions.length])
end

puts "  Created #{listings.count} marketplace listings (#{listings.count(&:seller_member?)} promoted)"
puts "Marketplace listings seeded successfully!"
