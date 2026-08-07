# Seed parking notifications and impound records around San Francisco for the Brakebills organization
brakebills = Organization.find_by_name("Brakebills")
member = User.find_by_email("member@brakebills.edu")
user = User.find_by_email("user@bikeindex.org")

raise "missing Brakebills org, test users, or manufacturers" if member.blank? || user.blank? || Manufacturer.none?

# Make member a member of Brakebills if not already
unless OrganizationRole.where(organization: brakebills, user: member).exists?
  OrganizationRole.create!(organization: brakebills, user: member, role: "member")
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

# Not @example.com: SpamEstimator scores RFC-reserved domains as 100, which
# would mark every seeded bike likely_spam and hide it from Bike's default scope
owner_emails = %w[
  alice@brakebills.edu bob@brakebills.edu carol@brakebills.edu dave@brakebills.edu
  eve@brakebills.edu frank@brakebills.edu grace@brakebills.edu heidi@brakebills.edu
  ivan@brakebills.edu judy@brakebills.edu kevin@brakebills.edu laura@brakebills.edu
  mike@brakebills.edu nora@brakebills.edu oscar@brakebills.edu
]

creator = BikeServices::Creator.new

def org_bike_params(owner_email:, creation_organization_id: Organization.find_by_name("Brakebills").id, manufacturer_id: nil)
  manufacturer_id ||= SeedHelpers.weighted_frame_maker_id
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

def seed_org_bike(creator:, user:, owner_email:, creation_organization_id: Organization.find_by_name("Brakebills").id, **bike_attrs)
  b_param = BParam.create!(creator: user, params: {bike: org_bike_params(owner_email:, creation_organization_id:).merge(bike_attrs)})
  b_param.origin = "organization_form"
  bike = creator.create_bike(b_param)
  raise "Bike creation failed: #{b_param.bike_errors}" if bike.errors.any?
  bike
end

# Register an unknown-serial bike together with its parking notification, the way
# the organized "unregistered" flow does (no ProcessParkingNotificationJob email).
def seed_unregistered_parking_notification(creator:, member:, owner_email:, loc:, kind:, region_record_id:, country_id:)
  b_param = BParam.create!(
    creator: member,
    params: {
      bike: org_bike_params(owner_email:).merge(serial_number: "unknown"),
      parking_notification: {kind:, street: loc[:street], city: loc[:city], postal_code: loc[:postal_code], region_record_id:, country_id:, skip_geocoding: true}
    }
  )
  b_param.origin = "organization_form"
  bike = creator.create_bike(b_param)
  raise "Unregistered bike creation failed: #{b_param.bike_errors}" if bike.errors.any?
  bike.parking_notifications.last&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  puts "  Created unregistered parking notification at #{loc[:street]}"
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
    organization: brakebills,
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
    organization: brakebills,
    kind: "impound_notification",
    initial_record_id: initial.id,
    street: loc[:street],
    city: loc[:city],
    postal_code: loc[:postal_code],
    region_record_id: ca_state&.id,
    country_id: us&.id,
    skip_geocoding: true,
    message: "Repeat notification - impounding bike from #{loc[:street]}"
  )
  pn.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  ProcessParkingNotificationJob.new.perform(pn.id)
  pn.reload
  pn.impound_record&.address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  puts "  Created impound notification ##{i + 1} with ImpoundRecord ##{pn.impound_record_id}"
end

# Create 2 unregistered_parking_notifications: one for the member, one owned by the primary test user
seed_unregistered_parking_notification(creator:, member:, owner_email: member.email, loc: sf_locations[10],
  kind: "parked_incorrectly_notification", region_record_id: ca_state&.id, country_id: us&.id)
seed_unregistered_parking_notification(creator:, member:, owner_email: user.email, loc: sf_locations[11],
  kind: "appears_abandoned_notification", region_record_id: ca_state&.id, country_id: us&.id)

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
# brakebills.bikes rather than bike_organizations: the unregistered parking
# notification bikes above are user_hidden, so their bike_organization.bike is nil
brakebills.bikes.limit(5).each_with_index do |bike, index|
  BikeOrganizationNote.upsert(bike:, organization: brakebills, body: sample_notes[index], user: member)
  puts "  Added note for bike ##{bike.id} in #{brakebills.short_name}"
end

# --- 5 impound records via BikeServices::Creator with status_impounded ---
puts "Creating 5 impound records in San Francisco for Brakebills..."

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

# --- Non-bike cycle types registered to Brakebills ---
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

# --- Bike Sticker Batch "BR" for Brakebills ---
puts "Creating bike sticker batch BR with 20 stickers..."
sticker_batch = BikeStickerBatch.create!(
  prefix: "BR",
  organization: brakebills,
  user: member,
  code_number_length: 4
)
sticker_batch.create_codes(20, initial_code_integer: 0)

# Assign 3 stickers to bikes
brakebills_bikes = brakebills.bikes.limit(3)
sticker_batch.bike_stickers.limit(3).each_with_index do |sticker, i|
  sticker.claim(user: member, bike: brakebills_bikes[i])
  puts "  Assigned sticker #{sticker.code} to bike ##{brakebills_bikes[i].id}"
end
puts "Bike sticker batch BR seeded with 20 stickers (3 assigned to bikes)"
