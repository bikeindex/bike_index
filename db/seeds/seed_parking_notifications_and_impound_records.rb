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

pn_kinds = %w[appears_abandoned_notification parked_incorrectly_notification appears_abandoned_notification parked_incorrectly_notification]

owner_emails = %w[
  alice@example.com bob@example.com carol@example.com dave@example.com
  eve@example.com frank@example.com grace@example.com heidi@example.com
  ivan@example.com judy@example.com kevin@example.com laura@example.com
  mike@example.com nora@example.com oscar@example.com
]

creator = BikeServices::Creator.new

# Helper to create a bike via BikeServices::Creator
create_bike = lambda {
  b_param = BParam.create!(
    creator: user,
    params: {
      bike: {
        cycle_type: "bike",
        propulsion_type: "foot-pedal",
        serial_number: (0...10).map { rand(65..90).chr }.join,
        manufacturer_id: manufacturer_ids.sample.to_s,
        primary_frame_color_id: color_ids.sample.to_s,
        rear_tire_narrow: "true",
        handlebar_type: HandlebarType.slugs.first,
        owner_email: owner_emails.sample,
        creation_organization_id: hogwarts.id.to_s
      }
    }
  )
  b_param.origin = "organization_form"
  bike = creator.create_bike(b_param)
  raise "Bike creation failed: #{b_param.bike_errors}" if bike.errors.any?
  bike
}

puts "Creating parking notifications in San Francisco..."

# Create 10 initial parking notifications
initial_notifications = []
10.times do |i|
  loc = sf_locations[i]
  bike = create_bike.call
  pn = ParkingNotification.create!(
    bike:,
    user: member,
    organization: hogwarts,
    kind: pn_kinds[i % pn_kinds.length],
    street: loc[:street],
    city: loc[:city],
    zipcode: loc[:zipcode],
    state_id: ca_state&.id,
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
    zipcode: loc[:zipcode],
    state_id: ca_state&.id,
    country_id: us&.id,
    skip_geocoding: true,
    message: "Repeat notification - impounding bike from #{loc[:street]}",
    delivery_status: "email_success"
  )
  pn.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  ProcessParkingNotificationJob.new.perform(pn.id)
  puts "  Created impound notification ##{i + 1} with ImpoundRecord ##{pn.reload.impound_record_id}"
end

# Create 1 unregistered_parking_notification via BikeServices::Creator
loc = sf_locations[10]
unreg_b_param = BParam.create!(
  creator: member,
  params: {
    bike: {
      cycle_type: "bike",
      propulsion_type: "foot-pedal",
      serial_number: "unknown",
      manufacturer_id: manufacturer_ids.sample.to_s,
      primary_frame_color_id: color_ids.sample.to_s,
      rear_tire_narrow: "true",
      handlebar_type: HandlebarType.slugs.first,
      owner_email: member.email,
      creation_organization_id: hogwarts.id.to_s
    },
    parking_notification: {
      kind: "parked_incorrectly_notification",
      street: loc[:street],
      city: loc[:city],
      zipcode: loc[:zipcode],
      state_id: ca_state&.id,
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

# --- 5 impound records via BikeServices::Creator with status_impounded ---
puts "Creating 5 impound records in San Francisco for Hogwarts..."

5.times do |i|
  loc = sf_locations[i]
  b_param = BParam.create!(
    creator: member,
    params: {
      bike: {
        cycle_type: "bike",
        propulsion_type: "foot-pedal",
        serial_number: (0...10).map { rand(65..90).chr }.join,
        manufacturer_id: manufacturer_ids.sample.to_s,
        primary_frame_color_id: color_ids.sample.to_s,
        rear_tire_narrow: "true",
        handlebar_type: HandlebarType.slugs.first,
        owner_email: owner_emails.sample,
        creation_organization_id: hogwarts.id.to_s,
        status: "status_impounded"
      },
      impound_record: {
        address_record_attributes: {
          street: loc[:street],
          city: loc[:city],
          zipcode: loc[:zipcode],
          state_id: ca_state&.id.to_s,
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
  impound_record.address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  impound_record.impounded_from_address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
  ProcessImpoundUpdatesJob.new.perform(impound_record.id)
  puts "  Created impound record ##{i + 1} at #{loc[:street]}, #{loc[:city]}"
end

puts "Impound records seeded successfully!"
