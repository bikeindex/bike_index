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

# San Francisco locations (lat/lng pairs with street addresses)
sf_locations = [
  {latitude: 37.7749, longitude: -122.4194, street: "1 Market St", city: "San Francisco", postal_code: "94105"},
  {latitude: 37.7851, longitude: -122.4094, street: "345 Stockton St", city: "San Francisco", postal_code: "94108"},
  {latitude: 37.7694, longitude: -122.4862, street: "1001 Great Hwy", city: "San Francisco", postal_code: "94121"},
  {latitude: 37.7599, longitude: -122.4148, street: "2501 Mission St", city: "San Francisco", postal_code: "94110"},
  {latitude: 37.8024, longitude: -122.4058, street: "Pier 39", city: "San Francisco", postal_code: "94133"},
  {latitude: 37.7695, longitude: -122.4529, street: "750 Judah St", city: "San Francisco", postal_code: "94122"},
  {latitude: 37.7840, longitude: -122.4089, street: "77 Maiden Ln", city: "San Francisco", postal_code: "94108"},
  {latitude: 37.7683, longitude: -122.4539, street: "1350 9th Ave", city: "San Francisco", postal_code: "94122"},
  {latitude: 37.7956, longitude: -122.3933, street: "100 The Embarcadero", city: "San Francisco", postal_code: "94105"},
  {latitude: 37.7589, longitude: -122.4380, street: "3201 24th St", city: "San Francisco", postal_code: "94110"},
  {latitude: 37.7736, longitude: -122.4312, street: "55 Haight St", city: "San Francisco", postal_code: "94102"},
  {latitude: 37.7879, longitude: -122.4074, street: "870 Market St", city: "San Francisco", postal_code: "94102"},
  {latitude: 37.7616, longitude: -122.4346, street: "3100 Mission St", city: "San Francisco", postal_code: "94110"}
]

pn_kinds = %w[appears_abandoned_notification parked_incorrectly_notification appears_abandoned_notification parked_incorrectly_notification]

owner_emails = %w[
  alice@example.com bob@example.com carol@example.com dave@example.com
  eve@example.com frank@example.com grace@example.com heidi@example.com
  ivan@example.com judy@example.com kevin@example.com laura@example.com
  mike@example.com nora@example.com oscar@example.com
]

creator = BikeServices::Creator.new

def org_bike_params(owner_email:, creation_organization_id: Organization.find_by_name("Hogwarts").id, manufacturer_id: nil)
  manufacturer_id ||= Manufacturer.frame_makers.pluck(:id).sample
  {
    cycle_type: "bike",
    propulsion_type: "foot-pedal",
    serial_number: (0...10).map { rand(65..90).chr }.join,
    manufacturer_id:,
    primary_frame_color_id: Color.pluck(:id).sample,
    rear_tire_narrow: "true",
    handlebar_type: HandlebarType.slugs.first,
    owner_email:,
    creation_organization_id: creation_organization_id.to_s
  }
end

def seed_org_bike(creator:, user:, owner_email:, creation_organization_id: Organization.find_by_name("Hogwarts").id, **bike_attrs)
  b_param = BParam.create!(creator: user, params: {bike: org_bike_params(owner_email:, creation_organization_id:).merge(bike_attrs)})
  b_param.origin = "organization_form"
  bike = creator.create_bike(b_param)
  raise "Bike creation failed: #{b_param.bike_errors}" if bike.errors.any?
  bike
end

puts "Creating parking notifications in San Francisco..."

# Create 10 initial parking notifications
initial_notifications = []
10.times do |i|
  loc = sf_locations[i]
  bike = seed_org_bike(creator:, user:, owner_email: owner_emails.sample)
  pn = ParkingNotification.create!(
    bike:,
    user: member,
    organization: hogwarts,
    kind: pn_kinds[i % pn_kinds.length],
    street: loc[:street],
    city: loc[:city],
    postal_code: loc[:postal_code],
    region_record_id: ca_state&.id,
    country_id: us&.id,
    skip_geocoding: true,
    message: "Bike found #{loc[:street]} - notification ##{i + 1}"
  )
  pn.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  initial_notifications << pn
  puts "  Created parking notification ##{i + 1} at #{loc[:street]}"
end

# Create 2 impound notifications (ProcessParkingNotificationJob creates the impound records)
2.times do |i|
  initial = initial_notifications[i]
  loc = sf_locations[i]
  pn = ParkingNotification.create!(
    bike_id: initial.bike_id,
    user: member,
    organization: hogwarts,
    kind: "impound_notification",
    initial_record_id: initial.id,
    street: loc[:street],
    city: loc[:city],
    postal_code: loc[:postal_code],
    region_record_id: ca_state&.id,
    country_id: us&.id,
    skip_geocoding: true,
    message: "Repeat notification - impounding bike from #{loc[:street]}",
    delivery_status: "email_success"
  )
  pn.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  ProcessParkingNotificationJob.new.perform(pn.id)
  pn.reload
  pn.impound_record&.address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  puts "  Created impound notification ##{i + 1} with ImpoundRecord ##{pn.impound_record_id}"
end

# Create 1 unregistered_parking_notification via BikeServices::Creator
loc = sf_locations[10]
unreg_b_param = BParam.create!(
  creator: member,
  params: {
    bike: org_bike_params(owner_email: member.email)
      .merge(serial_number: "unknown"),
    parking_notification: {
      kind: "parked_incorrectly_notification",
      street: loc[:street],
      city: loc[:city],
      postal_code: loc[:postal_code],
      region_record_id: ca_state&.id,
      country_id: us&.id,
      skip_geocoding: true
    }
  }
)
unreg_b_param.origin = "organization_form"
unreg_bike = creator.create_bike(unreg_b_param)
raise "Unregistered bike creation failed: #{unreg_b_param.bike_errors}" if unreg_bike.errors.any?
unreg_bike.parking_notifications.last&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
puts "  Created unregistered parking notification at #{loc[:street]}"

puts "Parking notifications seeded successfully!"

# --- Add notes to some bike_organizations ---
puts "Adding notes to bike organizations..."
sample_notes = [
  "Always parks near the library",
  "Has a red lock and basket",
  "Student employee - building access",
  "Frequent visitor, registered at orientation",
  "Needs new sticker - old one damaged"
]
hogwarts.bike_organizations.limit(5).each_with_index do |bike_organization, index|
  BikeOrganizationNote.upsert(bike: bike_organization.bike, organization: bike_organization.organization, body: sample_notes[index], user: member)
  puts "  Added note for bike ##{bike_organization.bike_id} in #{bike_organization.organization.short_name}"
end

# --- 5 impound records via BikeServices::Creator with status_impounded ---
puts "Creating 5 impound records in San Francisco for Hogwarts..."

5.times do |i|
  loc = sf_locations[i]
  b_param = BParam.create!(
    creator: member,
    params: {
      bike: org_bike_params(owner_email: owner_emails.sample)
        .merge(status: "status_impounded"),
      impound_record: {
        address_record_attributes: {
          street: loc[:street],
          city: loc[:city],
          postal_code: loc[:postal_code],
          region_record_id: ca_state&.id.to_s,
          country_id: us&.id.to_s,
          skip_geocoding: true
        }
      }
    }
  )
  b_param.origin = "organization_form"
  bike = creator.create_bike(b_param)
  raise "Impound bike creation failed: #{b_param.bike_errors}" if bike.errors.any?
  impound_record = bike.current_impound_record
  ProcessImpoundUpdatesJob.new.perform(impound_record.id)
  impound_record.reload
  impound_record.address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  impound_record.impounded_from_address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  puts "  Created impound record ##{i + 1} at #{loc[:street]}, #{loc[:city]}"
end

puts "Impound records seeded successfully!"

# --- Non-bike cycle types registered to Hogwarts ---
puts "Seeding non-cycle types and e-vehicles"
[
  {cycle_type: "e-scooter", propulsion_type: "foot-pedal"},
  {cycle_type: "e-scooter", propulsion_type: "foot-pedal"},
  {cycle_type: "e-scooter", propulsion_type: "foot-pedal"},
  {cycle_type: "personal-mobility", propulsion_type: "foot-pedal"},
  {cycle_type: "cargo", propulsion_type: "pedal-assist"},
  {cycle_type: "cargo-rear", propulsion_type: "pedal-assist"},
  {cycle_type: "cargo-trike", propulsion_type: "pedal-assist-and-throttle"}
].each do |type|
  bike = seed_org_bike(creator:, user:, owner_email: owner_emails.sample, cycle_type: type[:cycle_type], propulsion_type: type[:propulsion_type])
  FindOrCreateModelAuditJob.new.perform(bike.id)
end

# --- Bike Sticker Batch "HO" for Hogwarts ---
puts "Creating bike sticker batch HO with 20 stickers..."
sticker_batch = BikeStickerBatch.create!(
  prefix: "HO",
  organization: hogwarts,
  user: member,
  code_number_length: 4
)
sticker_batch.create_codes(20, initial_code_integer: 0)

# Assign 3 stickers to bikes
hogwarts_bikes = hogwarts.bikes.limit(3)
sticker_batch.bike_stickers.limit(3).each_with_index do |sticker, i|
  sticker.claim(user: member, bike: hogwarts_bikes[i])
  puts "  Assigned sticker #{sticker.code} to bike ##{hogwarts_bikes[i].id}"
end
puts "Bike sticker batch HO seeded with 20 stickers (3 assigned to bikes)"
