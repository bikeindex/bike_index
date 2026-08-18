# Seed 25 bikes for user@bikeindex.org on the first organization,
# plus stolen bikes in SF/Oakland and found bikes
user = User.find_by_email("user@bikeindex.org")
raise "No manufacturers imported - run `bin/rake setup:import_spreadsheets` first" if Manufacturer.frame_makers.none?

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
# phone_visibility puts both ends of Bike#phoneable_by? in dev — police-only and public
stolen_locations = [
  {latitude: 37.7749, longitude: -122.4194, street: "50 Fremont St", city: "San Francisco", zipcode: "94105",
   phone_visibility: {phone_for_users: false, phone_for_shops: false}},
  {latitude: 37.7833, longitude: -122.4167, street: "200 Kearny St", city: "San Francisco", zipcode: "94108",
   phone_visibility: {phone_for_everyone: true}},
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
        phone: "111 222 3333",
        theft_description: "Bike was locked on #{loc[:street]} and stolen overnight",
        locking_description: StolenRecord::LOCKING_DESCRIPTIONS.sample,
        lock_defeat_description: StolenRecord::LOCKING_DEFEAT_DESCRIPTIONS.sample
      }.merge(loc[:phone_visibility].to_h)
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

# --- 1 found bike reported by the primary test user (user@bikeindex.org) ---
puts "Creating found bike reported by user@bikeindex.org..."
found_bike_location = {latitude: 37.7691, longitude: -122.4449, street: "1000 Stanyan St", city: "San Francisco", zipcode: "94117"}
specialized_manufacturer = Manufacturer.friendly_find("Specialized")

user_found_bike = seed_bike(
  creator:, user:, label: "Found bike",
  params: {
    bike: bike_params(owner_email: user.email, manufacturer_id: specialized_manufacturer&.id).merge(
      frame_model: "Sirrus",
      description: "Found unlocked near the Golden Gate Park tennis courts",
      status: "status_impounded"
    ),
    impound_record: {
      address_record_attributes: {
        street: found_bike_location[:street],
        city: found_bike_location[:city],
        zipcode: found_bike_location[:zipcode],
        state_id: ca_state&.id.to_s,
        country_id: us&.id.to_s,
        skip_geocoding: true
      }
    }
  }
)
unless user_found_bike.errors.any?
  impound_record = user_found_bike.current_impound_record
  ProcessImpoundUpdatesJob.new.perform(impound_record.id)
  impound_record.reload
  impound_record.address_record&.update_columns(latitude: found_bike_location[:latitude], longitude: found_bike_location[:longitude])
  puts "  Created found bike at #{found_bike_location[:street]}, #{found_bike_location[:city]}"
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

# --- Specific real bike: Riese & Müller Load4 75 rohloff cargo e-bike (child carrying) ---
puts "Creating Riese & Müller Load4 75 rohloff cargo bike..."
rm_manufacturer = Manufacturer.friendly_find("Riese & Müller")
brakebills_org = Organization.friendly_find("Brakebills")
grey = Color.friendly_find("Silver, gray or bare metal")
child_carrying_activity = PrimaryActivity.friendly_find("Child Carrying")
twenty_inch_id = WheelSize.id_for_bsd(406) # front "20 inch"
twenty_six_inch_id = WheelSize.id_for_bsd(559) # rear "26 inch"

# Stock build spec from Riese & Müller's Load4 75 rohloff (2023, universal size)
rm_components = [
  {ctype: "Bashguard/Chain Guide", description: "Riemenschutzring"},
  {ctype: "Bell/Noisemaker", description: "Billy"},
  {ctype: "Brake", manufacturer: "Tektro", front: true, rear: true, description: "Tektro TRP C 2.3 disc brake"},
  {ctype: "Chainrings", description: "55T, for Gates drive belt CDX"},
  {ctype: "Cog/Cassette/Freewheel", rear: true, description: "19T, for Gates drive belt CDX"},
  {ctype: "Crankset", description: "FSA/Riese & Müller, 170 mm"},
  {ctype: "Drive Belt", description: "Gates drive belt CDX"},
  {ctype: "E-vehicle Battery", description: "Akku Bosch PowerPack Frame 725"},
  {ctype: "E-vehicle Display/Remote", manufacturer: "Bosch", description: "Bosch Purion 200"},
  {ctype: "E-vehicle Motor", manufacturer: "Bosch", description: "Bosch Cargo Line (smart system)"},
  {ctype: "Fender", manufacturer: "SKS", description: "SKS A65R"},
  {ctype: "Fork", description: "Suntour Mobie 34 CGO Boost, 20\", 80mm"},
  {ctype: "Grips/Tape", manufacturer: "Ergon", description: "Ergon ergonomic"},
  {ctype: "Handlebar", manufacturer: "Satori", description: "Satori Horizon, 31,8 mm, 9°, B=620 mm"},
  {ctype: "Headset", manufacturer: "Acros", description: "Acros AZX-221, block lock"},
  {ctype: "Hub", front: true, description: "Novatec Boost Cargo Disc 32H"},
  {ctype: "Hub", manufacturer: "Rohloff", rear: true, description: "Rohloff Speedhub E14, 14-speed, 36H"},
  {ctype: "Kickstand", description: "Kickstand Riese & Müller"},
  {ctype: "Lights", manufacturer: "Supernova Bikes", front: true, description: "Supernova M99 Mini Pro-25"},
  {ctype: "Lights", manufacturer: "Supernova Bikes", rear: true, description: "Supernova M99, integrated brake light"},
  {ctype: "Pedals", description: "VP R&M Custom"},
  {ctype: "Rack", manufacturer: "Riese & Müller", description: "Riese & Müller luggage rack"},
  {ctype: "Rear Suspension", manufacturer: "X-Fusion", rear: true, description: "X-Fusion Glyde"},
  {ctype: "Rim", front: true, description: "Mach1 Trucky30 20\""},
  {ctype: "Rim", rear: true, description: "Mach1 Trucky30 26\""},
  {ctype: "Saddle", manufacturer: "Selle Royal", description: "Selle Royal Essenza Moderate"},
  {ctype: "Seatpost", description: "JD/Riese & Müller, Alu, 34,9 x 430mm"},
  {ctype: "Seatpost Clamp", description: "JD, 40,0 mm, QR"},
  {ctype: "Shifter", manufacturer: "Rohloff", description: "Rohloff E14 electronic shifter"},
  {ctype: "Spokes", description: "Sapim Leader 2,0 mm, Inox, black"},
  {ctype: "Stem", manufacturer: "Riese & Müller", description: "Riese & Müller, adjustable height and angle"},
  {ctype: "Tire", manufacturer: "Schwalbe", front: true, description: "Schwalbe Big Ben Plus 55-406 Reflex"},
  {ctype: "Tire", manufacturer: "Schwalbe", rear: true, description: "Schwalbe Big Ben Plus 55-559 Reflex"},
  {ctype: "Tube", manufacturer: "Schwalbe", description: "Schwalbe AV7"},
  {ctype: "unknown", description: "Bibia rubber"},
  {ctype: "unknown", manufacturer: "Abus", description: "ABUS Shield X+ lock"},
  {ctype: "unknown", description: "RX Chip (für RX Services)"}
]

rm_bike = seed_bike(
  creator:, user:, origin: "organization_form", label: "Riese & Müller bike",
  params: {bike: bike_params(owner_email: "user_3@gmail.com", manufacturer_id: rm_manufacturer.id).merge(
    creation_organization_id: brakebills_org.id.to_s,
    cycle_type: "cargo",
    propulsion_type: "pedal-assist",
    primary_frame_color_id: grey&.id,
    year: 2023,
    frame_model: "Load4 75 rohloff",
    frame_material_slug: "aluminum",
    handlebar_type: "flat",
    primary_activity_id: child_carrying_activity&.id,
    rear_tire_narrow: "false",
    front_tire_narrow: "false",
    front_gear_type_slug: "1",
    rear_gear_type_slug: "14-internal",
    front_wheel_size_id: twenty_inch_id,
    rear_wheel_size_id: twenty_six_inch_id,
    description: "Bosch Cargo Line mid-drive (Class 1) with 725Wh PowerPack, Rohloff Speedhub E14 14-speed internal hub and Gates CDX belt drive. Aluminum frame with front box cargo area, 200kg max total weight, SKS fenders, Supernova lights."
  )}
)

["riese_muller_load4_with_passenger.jpg", "riese_muller_load4.jpg"].each_with_index do |filename, i|
  public_image = PublicImage.new(imageable: rm_bike, listing_order: i + 1)
  File.open(Rails.root.join("db/seeds/images", filename)) { |file| public_image.image = file }
  public_image.save!
end
rm_components.each do |component|
  manufacturer = Manufacturer.friendly_find(component[:manufacturer])
  rm_bike.components.create!(
    ctype: Ctype.friendly_find(component[:ctype]),
    manufacturer: manufacturer || Manufacturer.other,
    manufacturer_other: manufacturer ? nil : component[:manufacturer],
    description: component[:description],
    front: component[:front],
    rear: component[:rear],
    is_stock: true,
    setting_is_stock: true
  )
end
puts "  Created Riese & Müller Load4 with #{rm_bike.components.count} components"

puts "Bikes seeded successfully!"
