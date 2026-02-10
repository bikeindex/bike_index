# Seed stolen bikes in San Francisco and Oakland, and found bikes
user = User.find_by_email("user@example.com")

if user.blank? || Manufacturer.none?
  puts "Skipping stolen/found bike seeds (missing user@example.com or manufacturers)"
else
  us = Country.united_states
  ca_state = State.find_by_abbreviation("CA")

  sf_stolen_locations = [
    {latitude: 37.7749, longitude: -122.4194, street: "50 Fremont St", city: "San Francisco", zipcode: "94105"},
    {latitude: 37.7833, longitude: -122.4167, street: "200 Kearny St", city: "San Francisco", zipcode: "94108"},
    {latitude: 37.7599, longitude: -122.4148, street: "2800 Mission St", city: "San Francisco", zipcode: "94110"},
    {latitude: 37.7694, longitude: -122.4862, street: "800 Great Hwy", city: "San Francisco", zipcode: "94121"},
    {latitude: 37.7956, longitude: -122.3933, street: "55 The Embarcadero", city: "San Francisco", zipcode: "94105"}
  ]

  oakland_stolen_locations = [
    {latitude: 37.8044, longitude: -122.2712, street: "1221 Broadway", city: "Oakland", zipcode: "94612"},
    {latitude: 37.8136, longitude: -122.2614, street: "400 Grand Ave", city: "Oakland", zipcode: "94610"},
    {latitude: 37.7984, longitude: -122.2633, street: "200 Lake Park Ave", city: "Oakland", zipcode: "94610"},
    {latitude: 37.8116, longitude: -122.2688, street: "1900 Telegraph Ave", city: "Oakland", zipcode: "94612"},
    {latitude: 37.7969, longitude: -122.2753, street: "500 14th St", city: "Oakland", zipcode: "94612"}
  ]

  all_stolen_locations = sf_stolen_locations + oakland_stolen_locations

  puts "Creating 10 stolen bikes in San Francisco and Oakland..."

  manufacturer_ids = Manufacturer.frame_makers.pluck(:id)
  color_ids = Color.pluck(:id)

  all_stolen_locations.each_with_index do |loc, i|
    bike = Bike.create!(
      cycle_type: :bike,
      propulsion_type: "foot-pedal",
      serial_number: (0...10).map { rand(65..90).chr }.join,
      manufacturer_id: manufacturer_ids.sample || Manufacturer.first.id,
      primary_frame_color_id: color_ids.sample,
      rear_tire_narrow: true,
      handlebar_type: HandlebarType.slugs.first,
      creator: user,
      owner_email: user.email
    )
    Ownership.create!(bike:, creator: user, owner_email: user.email, current: true, skip_email: true)

    stolen_record = StolenRecord.create!(
      bike:,
      date_stolen: Time.current - rand(1..30).days,
      latitude: loc[:latitude],
      longitude: loc[:longitude],
      street: loc[:street],
      city: loc[:city],
      zipcode: loc[:zipcode],
      state_id: ca_state&.id,
      country_id: us&.id,
      theft_description: "Bike was locked on #{loc[:street]} and stolen overnight",
      locking_description: StolenRecord::LOCKING_DESCRIPTIONS.sample,
      lock_defeat_description: StolenRecord::LOCKING_DEFEAT_DESCRIPTIONS.sample,
      skip_update: true
    )
    bike.update!(current_stolen_record: stolen_record)
    puts "  Created stolen bike ##{i + 1} at #{loc[:street]}, #{loc[:city]}"
  end

  # Create 2 found bikes (impound records without organization = "found")
  found_locations = [
    {latitude: 37.7736, longitude: -122.4312, street: "100 Page St", city: "San Francisco", zipcode: "94102"},
    {latitude: 37.8044, longitude: -122.2712, street: "550 12th St", city: "Oakland", zipcode: "94607"}
  ]

  puts "Creating 2 found bikes (1 San Francisco, 1 Oakland)..."

  found_locations.each_with_index do |loc, i|
    bike = Bike.create!(
      cycle_type: :bike,
      propulsion_type: "foot-pedal",
      serial_number: (0...10).map { rand(65..90).chr }.join,
      manufacturer_id: manufacturer_ids.sample || Manufacturer.first.id,
      primary_frame_color_id: color_ids.sample,
      rear_tire_narrow: true,
      handlebar_type: HandlebarType.slugs.first,
      creator: user,
      owner_email: user.email
    )
    Ownership.create!(bike:, creator: user, owner_email: user.email, current: true, skip_email: true)

    impound_record = ImpoundRecord.create!(
      bike:,
      user:,
      skip_update: true
    )
    bike.update!(current_impound_record: impound_record)
    puts "  Created found bike ##{i + 1} at #{loc[:street]}, #{loc[:city]}"
  end

  puts "Stolen and found bikes seeded successfully!"
end
