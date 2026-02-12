# Seed 50 bikes for user@bikeindex.org on the first organization,
# plus stolen bikes in SF/Oakland and found bikes
user = User.find_by_email("user@bikeindex.org")
member = User.find_by_email("member@bikeindex.org")
org = Organization.first
manufacturer_ids = Manufacturer.frame_makers.pluck(:id)
raise "No manufacturers imported - run `rails seed:import_manufacturers` first" if manufacturer_ids.blank?

wheel_size_ids = WheelSize.pluck(:id)
color_ids = Color.pluck(:id)

# --- 50 registered bikes ---
50.times do
  bike = Bike.new(
    cycle_type: :bike,
    propulsion_type: "foot-pedal",
    manufacturer_id: manufacturer_ids.sample,
    rear_tire_narrow: true,
    handlebar_type: HandlebarType.slugs.first,
    rear_wheel_size_id: wheel_size_ids.sample,
    front_wheel_size_id: wheel_size_ids.sample,
    primary_frame_color_id: color_ids.sample,
    creator: user,
    owner_email: user.email
  )
  bike.serial_number = (0...10).map { rand(65..90).chr }.join
  bike.creation_organization_id = org.id
  if bike.save
    ownership = Ownership.new(bike_id: bike.id, creator_id: member.id, user_id: user.id, owner_email: user.email, current: true, skip_email: true)
    unless ownership.save
      puts "\n Ownership error \n #{ownership.errors.messages}"
      raise StandardError
    end
    puts "New bike made by #{bike.manufacturer.name}"
  else
    puts "\n Bike error \n #{bike.errors.messages}"
  end
end

# --- 10 stolen bikes in San Francisco and Oakland ---
us = Country.united_states
ca_state = State.find_by_abbreviation("CA")

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

# --- 2 found bikes (impound records without organization) ---
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

Bike.pluck(:id).each { |b| CallbackJob::AfterBikeSaveJob.perform_async(b) }
puts "Bikes seeded successfully!"
