# Seed parking notifications around San Francisco for the Hogwarts organization
hogwarts = Organization.find_by_name("Hogwarts")
member = User.find_by_email("member@example.com")
user = User.find_by_email("user@example.com")

if hogwarts.blank? || member.blank? || user.blank?
  puts "Skipping parking notification seeds (missing Hogwarts org or test users)"
else
  # Make member a member of Hogwarts if not already
  unless OrganizationRole.where(organization: hogwarts, user: member).exists?
    OrganizationRole.create!(organization: hogwarts, user: member, role: "member")
  end

  us = Country.united_states
  ca_state = State.find_by_abbreviation("CA")

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
      manufacturer_id: Manufacturer.frame_makers.sample&.id || Manufacturer.first.id,
      primary_frame_color_id: Color.pluck(:id).sample,
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
      message: "Bike found #{loc[:street]} - notification ##{i + 1}",
      skip_update: true
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
      message: "Repeat notification - impounding bike from #{loc[:street]}",
      skip_update: true
    )
    # Create the impound record (normally done by ProcessParkingNotificationJob)
    impound_record = ImpoundRecord.create!(
      bike_id: initial.bike_id,
      user: member,
      organization: hogwarts,
      skip_update: true
    )
    pn.update!(impound_record:, skip_update: true)
    initial.update!(resolved_at: Time.current, skip_update: true)
    puts "  Created repeat impound notification ##{i + 1} with ImpoundRecord ##{impound_record.id}"
  end

  # Create 1 unregistered_parking_notification
  loc = sf_locations[10]
  unreg_bike = Bike.create!(
    cycle_type: :bike,
    propulsion_type: "foot-pedal",
    serial_number: "unknown",
    manufacturer_id: Manufacturer.frame_makers.sample&.id || Manufacturer.first.id,
    primary_frame_color_id: Color.pluck(:id).sample,
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
    unregistered_bike: true,
    skip_update: true
  )
  puts "  Created unregistered parking notification at #{loc[:street]}"

  puts "Parking notifications seeded successfully!"
end
