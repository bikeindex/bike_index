# Seed parking notifications and impound records around San Francisco for the Hogwarts organization
hogwarts = Organization.find_by_name("Hogwarts")
member = User.find_by_email("member@bikeindex.org")
user = User.find_by_email("user@bikeindex.org")

raise "missing Hogwarts org, test users, or manufacturers" if member.blank? || user.blank? || Manufacturer.none?

# Make member a member of Hogwarts if not already
unless OrganizationRole.where(organization: hogwarts, user: member).exists?
  OrganizationRole.create!(organization: hogwarts, user: member, role: "member")
end

us = Country.united_states
ca_state = State.find_by_abbreviation("CA")
manufacturer_ids = Manufacturer.frame_makers.pluck(:id)
color_ids = Color.pluck(:id)

# San Francisco locations (lat/lng pairs with street addresses)
sf_locations = [
  {latitude: 37.7749, longitude: -122.4194, street: "1 Market St", city: "San Francisco", zipcode: "94105"},
  {latitude: 37.7851, longitude: -122.4094, street: "345 Stockton St", city: "San Francisco", zipcode: "94108"},
  {latitude: 37.7694, longitude: -122.4862, street: "1001 Great Hwy", city: "San Francisco", zipcode: "94121"},
  {latitude: 37.7599, longitude: -122.4148, street: "2501 Mission St", city: "San Francisco", zipcode: "94110"},
  {latitude: 37.8024, longitude: -122.4058, street: "Pier 39", city: "San Francisco", zipcode: "94133"},
  {latitude: 37.7695, longitude: -122.4529, street: "750 Judah St", city: "San Francisco", zipcode: "94122"},
  {latitude: 37.7840, longitude: -122.4089, street: "77 Maiden Ln", city: "San Francisco", zipcode: "94108"},
  {latitude: 37.7683, longitude: -122.4539, street: "1350 9th Ave", city: "San Francisco", zipcode: "94122"},
  {latitude: 37.7956, longitude: -122.3933, street: "100 The Embarcadero", city: "San Francisco", zipcode: "94105"},
  {latitude: 37.7589, longitude: -122.4380, street: "3201 24th St", city: "San Francisco", zipcode: "94110"},
  {latitude: 37.7736, longitude: -122.4312, street: "55 Haight St", city: "San Francisco", zipcode: "94102"},
  {latitude: 37.7879, longitude: -122.4074, street: "870 Market St", city: "San Francisco", zipcode: "94102"},
  {latitude: 37.7616, longitude: -122.4346, street: "3100 Mission St", city: "San Francisco", zipcode: "94110"}
]

kinds = %w[appears_abandoned_notification parked_incorrectly_notification appears_abandoned_notification parked_incorrectly_notification]

puts "Creating parking notifications in San Francisco..."

# Helper to create a bike for parking notifications
create_pn_bike = lambda {
  Bike.create!(
    cycle_type: :bike,
    propulsion_type: "foot-pedal",
    serial_number: (0...10).map { rand(65..90).chr }.join,
    manufacturer_id: manufacturer_ids.sample || Manufacturer.first.id,
    primary_frame_color_id: color_ids.sample,
    rear_tire_narrow: true,
    handlebar_type: HandlebarType.slugs.first,
    creator: user,
    owner_email: user.email
  ).tap do |bike|
    Ownership.create!(bike:, creator: user, owner_email: user.email, current: true, skip_email: true)
  end
}

# Create 10 initial parking notifications
initial_notifications = []
10.times do |i|
  loc = sf_locations[i]
  bike = create_pn_bike.call
  pn = ParkingNotification.create!(
    bike:,
    user: member,
    organization: hogwarts,
    kind: kinds[i % kinds.length],
    latitude: loc[:latitude],
    longitude: loc[:longitude],
    street: loc[:street],
    city: loc[:city],
    zipcode: loc[:zipcode],
    state_id: ca_state&.id,
    country_id: us&.id,
    message: "Bike found #{loc[:street]} - notification ##{i + 1}"
  )
  initial_notifications << pn
  puts "  Created parking notification ##{i + 1} at #{loc[:street]}"
end

# Create 2 repeat parking notifications that become impound notifications (creating impound records)
2.times do |i|
  initial = initial_notifications[i]
  loc = sf_locations[i]
  pn = ParkingNotification.create!(
    bike_id: initial.bike_id,
    user: member,
    organization: hogwarts,
    kind: "impound_notification",
    initial_record_id: initial.id,
    latitude: loc[:latitude],
    longitude: loc[:longitude],
    street: loc[:street],
    city: loc[:city],
    zipcode: loc[:zipcode],
    state_id: ca_state&.id,
    country_id: us&.id,
    message: "Repeat notification - impounding bike from #{loc[:street]}"
  )
  # Create the impound record (normally done by ProcessParkingNotificationJob)
  impound_record = ImpoundRecord.create!(
    bike_id: initial.bike_id,
    user: member,
    organization: hogwarts
  )
  pn.update!(impound_record:)
  initial.update!(resolved_at: Time.current)
  puts "  Created repeat impound notification ##{i + 1} with ImpoundRecord ##{impound_record.id}"
end

# Create 1 unregistered_parking_notification
loc = sf_locations[10]
unreg_bike = Bike.create!(
  cycle_type: :bike,
  propulsion_type: "foot-pedal",
  serial_number: "unknown",
  manufacturer_id: manufacturer_ids.sample || Manufacturer.first.id,
  primary_frame_color_id: color_ids.sample,
  rear_tire_narrow: true,
  handlebar_type: HandlebarType.slugs.first,
  creator: member,
  owner_email: member.email,
  status: "unregistered_parking_notification"
)
Ownership.create!(bike: unreg_bike, creator: member, owner_email: member.email, current: true, skip_email: true,
  user_hidden: true, origin: "creator_unregistered_parking_notification")
unreg_bike.update!(user_hidden: true)

ParkingNotification.create!(
  bike: unreg_bike,
  user: member,
  organization: hogwarts,
  kind: "parked_incorrectly_notification",
  latitude: loc[:latitude],
  longitude: loc[:longitude],
  street: loc[:street],
  city: loc[:city],
  zipcode: loc[:zipcode],
  state_id: ca_state&.id,
  country_id: us&.id,
  message: "Unregistered bike found at #{loc[:street]}",
  unregistered_bike: true
)
puts "  Created unregistered parking notification at #{loc[:street]}"

puts "Parking notifications seeded successfully!"

# --- 5 impound records with impounded_from addresses ---
sf_impound_addresses = [
  {latitude: 37.7749, longitude: -122.4194, street: "1 Market St", city: "San Francisco", postal_code: "94105"},
  {latitude: 37.7851, longitude: -122.4094, street: "345 Stockton St", city: "San Francisco", postal_code: "94108"},
  {latitude: 37.7694, longitude: -122.4862, street: "1001 Great Hwy", city: "San Francisco", postal_code: "94121"},
  {latitude: 37.7599, longitude: -122.4148, street: "2501 Mission St", city: "San Francisco", postal_code: "94110"},
  {latitude: 37.8024, longitude: -122.4058, street: "Pier 39", city: "San Francisco", postal_code: "94133"}
]

puts "Creating 5 impound records in San Francisco for Hogwarts..."

sf_impound_addresses.each_with_index do |addr, i|
  bike = create_pn_bike.call

  address_record = AddressRecord.create!(
    kind: :impounded_from,
    latitude: addr[:latitude],
    longitude: addr[:longitude],
    street: addr[:street],
    city: addr[:city],
    postal_code: addr[:postal_code],
    region_record: ca_state,
    country: us,
    organization: hogwarts,
    bike:,
    skip_geocoding: true
  )

  impound_record = ImpoundRecord.create!(
    bike:,
    user: member,
    organization: hogwarts,
    impounded_from_address_record: address_record
  )
  bike.update!(current_impound_record: impound_record)
  puts "  Created impound record ##{i + 1} at #{addr[:street]}, #{addr[:city]}"
end

puts "Impound records seeded successfully!"

