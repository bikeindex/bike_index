# Seed 25 bikes for user@bikeindex.org on the first organization,
# plus stolen bikes in SF/Oakland and found bikes
user = User.find_by_email("user@bikeindex.org")
raise "No manufacturers imported - run `bin/rake setup:import_manufacturers_csv` first" if Manufacturer.frame_makers.none?

us = Country.united_states
ca_state = State.find_by_abbreviation("CA")

creator = BikeServices::Creator.new

def bike_params(owner_email:, manufacturer_id: nil)
  manufacturer_id ||= SeedHelpers.weighted_frame_maker_id
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

# --- Specific real bike: 1975 Viner Special Professional (bikeindex.org/bikes/108243) ---
puts "Creating 1975 Viner Special Professional with photos..."
viner_manufacturer = Manufacturer.friendly_find("Viner")
orange = Color.friendly_find("Orange")

viner_bike = seed_bike(
  creator:, user:, label: "Viner bike",
  params: {bike: bike_params(owner_email: "user1@gmail.com", manufacturer_id: viner_manufacturer.id).merge(
    primary_frame_color_id: orange&.id,
    year: 1975,
    frame_model: "Special Professional",
    frame_material_slug: "steel",
    frame_size: "54cm",
    description: "Force except the ultegra cranks and trp brakes. Classy af"
  )}
)

Dir[Rails.root.join("db/seeds/images/viner_108243_*.jpg")].sort.each_with_index do |path, i|
  public_image = PublicImage.new(imageable: viner_bike, listing_order: i + 1)
  File.open(path) { |file| public_image.image = file }
  public_image.save!
end
puts "  Created Viner bike with #{viner_bike.public_images.count} images"

# --- Specific stolen bike: Trek Top Fuel 9.9 XX AXS in Oakland ---
puts "Creating stolen Trek Top Fuel 9.9 in Oakland..."
trek_manufacturer = Manufacturer.friendly_find("Trek")
black = Color.friendly_find("Black")
trek_activity = PrimaryActivity.friendly_find("Trail / All-Mountain") # "MTB: Trail / All-Mountain"
seven_hundred_c_id = WheelSize.id_for_bsd(622) # "700 C"
trek_location = {latitude: 37.8228, longitude: -122.2730, street: "1430 32nd St", city: "Oakland", zipcode: "94608"}

# Stock build spec from Trek's Top Fuel 9.9 XX AXS T-Type (29" / M-XL build)
trek_components = [
  {ctype: "fork", manufacturer: "RockShox", model: "Pike Ultimate", front: true, description: "DebonAir spring, Charger 3.1 RC2 damper, 44mm offset, Boost110, Maxle Stealth, 130mm travel"},
  {ctype: "rear suspension", manufacturer: "RockShox", model: "Deluxe Ultimate RCT", description: "185mm x 50mm"},
  {ctype: "wheel", manufacturer: "Bontrager", model: "Line Pro 30", front: true, description: "OCLV Mountain Carbon, Tubeless Ready, 6-bolt, Boost110, 15mm thru axle, 29\""},
  {ctype: "wheel", manufacturer: "Bontrager", model: "Line Pro 30", rear: true, description: "OCLV Mountain Carbon, Tubeless Ready, Rapid Drive 108, 6-bolt, SRAM XD driver, Boost148, 12mm thru axle, 29\""},
  {ctype: "tire", manufacturer: "Bontrager", model: "Montrose RSL XT", front: true, description: "Tubeless Ready, triple compound, aramid bead, 120 tpi, 29x2.40\""},
  {ctype: "tire", manufacturer: "Bontrager", model: "Gunnison RSL XT", rear: true, description: "Tubeless Ready, triple compound, aramid bead, 120 tpi, 29x2.40\""},
  {ctype: "chain", manufacturer: "SRAM", model: "XX Eagle", description: "T-Type, 12 speed"},
  {ctype: "crankset", manufacturer: "SRAM", model: "XX Eagle", description: "DUB, 30T, T-Type, 55mm chainline, 170mm length"},
  {ctype: "bottom bracket", manufacturer: "SRAM", model: "DUB MTB Wide", description: "73mm, BSA threaded"},
  {ctype: "derailleur", manufacturer: "SRAM", model: "XX SL Eagle AXS", rear: true, description: "T-Type"},
  {ctype: "brake", manufacturer: "SRAM", model: "Level Ultimate 4-piston hydraulic disc", front: true, rear: true},
  {ctype: "saddle", manufacturer: "Verse", model: "Short Pro", description: "carbon rails, 145mm width"},
  {ctype: "seatpost", manufacturer: "RockShox", model: "Reverb AXS", description: "170mm travel, wireless, 34.9mm, 480mm length"},
  {ctype: "pedals", manufacturer: "Shimano", model: "XTR XC PD-M9200"}
]

trek_bike = seed_bike(
  creator:, user:, label: "Stolen Trek bike",
  params: {
    bike: bike_params(owner_email: "user_2@gmail.com", manufacturer_id: trek_manufacturer.id).merge(
      primary_frame_color_id: black&.id,
      year: 2024,
      frame_model: "Top Fuel 9.9 XX AXS T-Type",
      frame_material_slug: "composite",
      handlebar_type: "flat",
      primary_activity_id: trek_activity&.id,
      frame_size: "m",
      frame_size_unit: "ordinal",
      rear_tire_narrow: "false",
      front_tire_narrow: "false",
      front_gear_type_slug: "1",
      rear_gear_type_slug: "12",
      front_wheel_size_id: seven_hundred_c_id,
      rear_wheel_size_id: seven_hundred_c_id,
      description: "OCLV Mountain Carbon, 120mm travel, RockShox Pike Ultimate fork and Deluxe Ultimate shock, SRAM XX SL Eagle AXS T-Type, Bontrager Line Pro 30 carbon wheels.",
      status: "status_stolen",
      date_stolen: (Time.current - 14.days).to_s
    ),
    stolen_record: {
      latitude: trek_location[:latitude].to_s,
      longitude: trek_location[:longitude].to_s,
      street: trek_location[:street],
      city: trek_location[:city],
      zipcode: trek_location[:zipcode],
      state_id: ca_state&.id.to_s,
      country_id: us&.id.to_s,
      skip_geocoding: true,
      estimated_value: "11000",
      theft_description: "Locked outside on #{trek_location[:street]} and stolen overnight",
      locking_description: StolenRecord::LOCKING_DESCRIPTIONS.sample,
      lock_defeat_description: StolenRecord::LOCKING_DEFEAT_DESCRIPTIONS.sample
    }
  }
)

trek_bike.current_stolen_record&.update_columns(latitude: trek_location[:latitude], longitude: trek_location[:longitude])
trek_image = PublicImage.new(imageable: trek_bike, listing_order: 1)
File.open(Rails.root.join("db/seeds/images/trek_top_fuel.jpg")) { |file| trek_image.image = file }
trek_image.save!
trek_components.each do |component|
  manufacturer = Manufacturer.friendly_find(component[:manufacturer])
  trek_bike.components.create!(
    ctype: Ctype.friendly_find(component[:ctype]),
    manufacturer: manufacturer || Manufacturer.other,
    manufacturer_other: manufacturer ? nil : component[:manufacturer],
    component_model: component[:model],
    description: component[:description],
    front: component[:front],
    rear: component[:rear],
    is_stock: true,
    setting_is_stock: true
  )
end
puts "  Created stolen Trek at #{trek_location[:street]}, #{trek_location[:city]} with #{trek_bike.components.count} components"

puts "Bikes seeded successfully!"
