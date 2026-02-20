# Seed 50 bikes for user@bikeindex.org on the first organization,
# plus stolen bikes in SF/Oakland and found bikes
user = User.find_by_email("user@bikeindex.org")
org = Organization.first
manufacturer_ids = Manufacturer.frame_makers.pluck(:id)
raise "No manufacturers imported - run `rails seed:import_manufacturers` first" if manufacturer_ids.blank?

wheel_size_ids = WheelSize.pluck(:id)
color_ids = Color.pluck(:id)
us = Country.united_states
ca_state = State.find_by_abbreviation("CA")

creator = BikeServices::Creator.new

# --- 50 registered bikes ---
50.times do |i|
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
        rear_wheel_size_id: wheel_size_ids.sample.to_s,
        front_wheel_size_id: wheel_size_ids.sample.to_s,
        handlebar_type: HandlebarType.slugs.first,
        owner_email: "testuser+#{i}@bikeindex.org",
        creation_organization_id: org.id.to_s
      }
    }
  )
  b_param.origin = "organization_form"
  bike = creator.create_bike(b_param)
  if bike.errors.any?
    puts "\n Bike error \n #{b_param.bike_errors}"
  else
    puts "New bike made by #{bike.manufacturer.name}"
  end
end

# --- 10 stolen bikes in San Francisco and Oakland ---
stolen_locations = [
  {latitude: 37.7749, longitude: -122.4194, street: "50 Fremont St", city: "San Francisco", zipcode: "94105"},
  {latitude: 37.7833, longitude: -122.4167, street: "200 Kearny St", city: "San Francisco", zipcode: "94108"},
  {latitude: 37.7599, longitude: -122.4148, street: "2800 Mission St", city: "San Francisco", zipcode: "94110"},
  {latitude: 37.7694, longitude: -122.4862, street: "800 Great Hwy", city: "San Francisco", zipcode: "94121"},
  {latitude: 37.7956, longitude: -122.3933, street: "55 The Embarcadero", city: "San Francisco", zipcode: "94105"},
  {latitude: 37.8044, longitude: -122.2712, street: "1221 Broadway", city: "Oakland", zipcode: "94612"},
  {latitude: 37.8136, longitude: -122.2614, street: "400 Grand Ave", city: "Oakland", zipcode: "94610"},
  {latitude: 37.7984, longitude: -122.2633, street: "200 Lake Park Ave", city: "Oakland", zipcode: "94610"},
  {latitude: 37.8116, longitude: -122.2688, street: "1900 Telegraph Ave", city: "Oakland", zipcode: "94612"},
  {latitude: 37.7969, longitude: -122.2753, street: "500 14th St", city: "Oakland", zipcode: "94612"}
]

puts "Creating 10 stolen bikes in San Francisco and Oakland..."

stolen_locations.each_with_index do |loc, i|
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
        owner_email: "testuser+#{i + 50}@bikeindex.org",
        status: "status_stolen",
        date_stolen: (Time.current - rand(1..30).days).to_s
      },
      stolen_record: {
        latitude: loc[:latitude].to_s,
        longitude: loc[:longitude].to_s,
        street: loc[:street],
        city: loc[:city],
        zipcode: loc[:zipcode],
        state_id: ca_state&.id.to_s,
        country_id: us&.id.to_s,
        skip_geocoding: true,
        theft_description: "Bike was locked on #{loc[:street]} and stolen overnight",
        locking_description: StolenRecord::LOCKING_DESCRIPTIONS.sample,
        lock_defeat_description: StolenRecord::LOCKING_DEFEAT_DESCRIPTIONS.sample
      }
    }
  )
  bike = creator.create_bike(b_param)
  if bike.errors.any?
    puts "\n Stolen bike error \n #{b_param.bike_errors}"
  else
    bike.current_stolen_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
    puts "  Created stolen bike ##{i + 1} at #{loc[:street]}, #{loc[:city]}"
  end
end

# --- 2 found bikes (impound records without organization) ---
found_locations = [
  {latitude: 37.7736, longitude: -122.4312, street: "100 Page St", city: "San Francisco", zipcode: "94102"},
  {latitude: 37.8044, longitude: -122.2712, street: "550 12th St", city: "Oakland", zipcode: "94607"}
]

puts "Creating 2 found bikes (1 San Francisco, 1 Oakland)..."

found_locations.each_with_index do |loc, i|
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
        owner_email: "testuser+#{i + 60}@bikeindex.org",
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
  bike = creator.create_bike(b_param)
  if bike.errors.any?
    puts "\n Found bike error \n #{b_param.bike_errors}"
  else
    impound_record = bike.current_impound_record
    ProcessImpoundUpdatesJob.new.perform(impound_record.id)
    impound_record.reload
    impound_record.address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
    puts "  Created found bike ##{i + 1} at #{loc[:street]}, #{loc[:city]}"
  end
end

puts "Bikes seeded successfully!"
