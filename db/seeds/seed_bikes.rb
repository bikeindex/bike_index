# Seed 25 bikes for user@bikeindex.org on the first organization,
# plus stolen bikes in SF/Oakland and found bikes
user = User.find_by_email("user@bikeindex.org")
org = Organization.friendly_find "Hogwarts"
raise "No manufacturers imported - run `bin/rake setup:import_manufacturers_csv` first" if Manufacturer.frame_makers.none?

us = Country.united_states
ca_state = State.find_by_abbreviation("CA")

creator = BikeServices::Creator.new

def bike_params(owner_email:, manufacturer_id: nil)
  manufacturer_id ||= Manufacturer.frame_makers.pluck(:id).sample
  {
    cycle_type: "bike",
    propulsion_type: "foot-pedal",
    serial_number: (0...10).map { rand(65..90).chr }.join,
    manufacturer_id:,
    primary_frame_color_id: Color.pluck(:id).sample,
    rear_tire_narrow: "true",
    handlebar_type: HandlebarType.slugs.first,
    owner_email:
  }
end

def seed_bike(creator:, user:, params:, origin: nil, label: "bike")
  b_param = BParam.create!(creator: user, params:)
  b_param.origin = origin if origin
  bike = creator.create_bike(b_param)
  if bike.errors.any?
    puts "\n #{label} error \n #{b_param.bike_errors}"
  end
  bike
end

# --- 25 registered bikes ---
25.times do |i|
  bike = seed_bike(
    creator:, user:, origin: "organization_form", label: "Bike",
    params: {bike: bike_params(owner_email: "testuser+#{i}@bikeindex.org")}
  )
  puts "New bike made by #{bike.manufacturer.name}" unless bike.errors.any?
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
  bike = seed_bike(
    creator:, user:, label: "Stolen bike",
    params: {
      bike: bike_params(owner_email: "testuser+#{i + 50}@bikeindex.org")
        .merge(status: "status_stolen", date_stolen: (Time.current - rand(1..30).days).to_s),
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
  unless bike.errors.any?
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
  bike = seed_bike(
    creator:, user:, label: "Found bike",
    params: {
      bike: bike_params(owner_email: "testuser+#{i + 60}@bikeindex.org")
        .merge(status: "status_impounded"),
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
  unless bike.errors.any?
    impound_record = bike.current_impound_record
    ProcessImpoundUpdatesJob.new.perform(impound_record.id)
    impound_record.reload
    impound_record.address_record&.update_columns(latitude: loc[:latitude], longitude: loc[:longitude])
    puts "  Created found bike ##{i + 1} at #{loc[:street]}, #{loc[:city]}"
  end
end

# --- 3 Cannondale bikes registered to Cannondale org ---
cannondale_org = Organization.friendly_find("Cannondale")
cannondale_manufacturer = Manufacturer.friendly_find("Cannondale")

puts "Creating 3 Cannondale bikes registered to Cannondale org..."
3.times do |i|
  bike = seed_bike(
    creator:, user:, origin: "organization_form", label: "Cannondale bike",
    params: {bike: bike_params(
      owner_email: "testuser+cannondale#{i}@bikeindex.org",
      manufacturer_id: cannondale_manufacturer.id
    ).merge(creation_organization_id: cannondale_org.id.to_s)}
  )
  puts "  Created Cannondale bike ##{i + 1}: #{bike.manufacturer.name}" unless bike.errors.any?
end

puts "Bikes seeded successfully!"
