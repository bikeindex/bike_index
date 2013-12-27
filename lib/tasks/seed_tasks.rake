# Seed the database with test things!
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.

desc "Seed test users"
task :seed_test_users => :environment do 
  user = User.create(name: "admin", email: "admin@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true)
  user.confirmed = true 
  user.superuser = true 
  user.save
  user = User.create(name: "member", email: "member@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true)
  user.confirmed = true 
  user.can_invite = true
  user.save
  user = User.create(name: "user", email: "user@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true)
  user.confirmed = true 
  user.save

  org = Organization.create(name: "Ikes Bike's", website: "", short_name: "Ikes", default_bike_token_count: 5, show_on_map: true)
  org.save
  membership = Membership.create(organization_id: org.id, user_id: User.find_by_email("member@example.com").id, role: "admin")
  membership.save
  puts "\nSuccess"
end

desc "Create test bikes for user@example on first organization"
task :seed_test_bikes => :environment do
  @user = User.find_by_email('user@example.com')
  @member = User.find_by_email('member@example.com')
  @org = Organization.first
  @propulsion_type_id = PropulsionType.find_by_name('Foot pedal').id
  @cycle_type_id = CycleType.find_by_name('Bike').id
  50.times do 
    bike = Bike.new(
      cycle_type_id: @cycle_type_id,
      propulsion_type_id: @propulsion_type_id,
      manufacturer_id: (rand(Manufacturer.frames.count) + 1),
      rear_tire_narrow: true,
      rear_wheel_size_id: (rand(WheelSize.count) + 1),
      front_wheel_size_id: (rand(WheelSize.count) + 1),
      primary_frame_color_id: (rand(Color.count) + 1),
      handlebar_type_id: (rand(HandlebarType.count) + 1),
      creator: @user,
      owner_email: @user.email,
      verified: true
    )
    bike.serial_number = (0...10).map{(65+rand(26)).chr}.join
    bike.creation_organization_id = @org.id
    if bike.save
      ownership = Ownership.new(bike_id: bike.id, creator_id: @member.id, user_id: @user.id, owner_email: @user.email, current: true)
      unless ownership.save
        puts "\n Ownership error \n #{ownership.errors.messages}"
        raise StandardError
      end
      puts "New bike made by #{bike.manufacturer.name}"
    else
      puts "\n Bike error \n #{bike.errors.messages}"
    end
  end
end

task :seed_dup_bikes => :environment do
  @user = User.find_by_email('user@example.com')
  @member = User.find_by_email('member@example.com')
  @org = Organization.first
  @propulsion_type_id = PropulsionType.find_by_name('Foot pedal').id
  @cycle_type_id = CycleType.find_by_name('Bike').id
  @serial_number = (0...10).map{(65+rand(26)).chr}.join
  @manufacturer_id = (rand(Manufacturer.frames.count) + 1)
  5.times do 
    bike = Bike.new(
      cycle_type_id: @cycle_type_id,
      propulsion_type_id: @propulsion_type_id,
      manufacturer_id: @manufacturer_id,
      rear_tire_narrow: true,
      rear_wheel_size_id: WheelSize.first.id,
      primary_frame_color_id: Color.first.id,
      handlebar_type_id: HandlebarType.first.id,
      creator: @user,
      owner_email: @user.email,
      serial_number: @serial_number
    )
    bike.organization_id = @org.id
    if bike.save
      ownership = Ownership.new(bike_id: bike.id, creator_id: @member.id, user_id: @user.id, owner_email: @user.email, current: true)
      unless ownership.save
        puts "\n Ownership error \n #{ownership.errors.messages}"
        raise StandardError
      end
      puts "New bike made by #{bike.manufacturer.name}"
    else
      puts "\n Bike error \n #{bike.errors.messages}"
    end
  end
end




desc "Seed states"
task :seed_us_states => :environment do 
  states = [  
    { name: 'Alabama', abbr: 'AL' },
    { name: 'Alaska', abbr: 'AK' },
    { name: 'Arizona', abbr: 'AZ' },
    { name: 'Arkansas', abbr: 'AR' },
    { name: 'California', abbr: 'CA' },
    { name: 'Colorado', abbr: 'CO' },
    { name: 'Connecticut', abbr: 'CT' },
    { name: 'Delaware', abbr: 'DE' },
    { name: 'District of Columbia', abbr: 'DC' },
    { name: 'Florida', abbr: 'FL' },
    { name: 'Georgia', abbr: 'GA' },
    { name: 'Hawaii', abbr: 'HI' },
    { name: 'Idaho', abbr: 'ID' },
    { name: 'Illinois', abbr: 'IL' },
    { name: 'Indiana', abbr: 'IN' },
    { name: 'Iowa', abbr: 'IA' },
    { name: 'Kansas', abbr: 'KS' },
    { name: 'Kentucky', abbr: 'KY' },
    { name: 'Louisiana', abbr: 'LA' },
    { name: 'Maine', abbr: 'ME' },
    { name: 'Maryland', abbr: 'MD' },
    { name: 'Massachusetts', abbr: 'MA' },
    { name: 'Michigan', abbr: 'MI' },
    { name: 'Minnesota', abbr: 'MN' },
    { name: 'Mississippi', abbr: 'MS' },
    { name: 'Missouri', abbr: 'MO' },
    { name: 'Montana', abbr: 'MT' },
    { name: 'Nebraska', abbr: 'NE' },
    { name: 'Nevada', abbr: 'NV' },
    { name: 'New Hampshire', abbr: 'NH' },
    { name: 'New Jersey', abbr: 'NJ' },
    { name: 'New Mexico', abbr: 'NM' },
    { name: 'New York', abbr: 'NY' },
    { name: 'North Carolina', abbr: 'NC' },
    { name: 'North Dakota', abbr: 'ND' },
    { name: 'Ohio', abbr: 'OH' },
    { name: 'Oklahoma', abbr: 'OK' },
    { name: 'Oregon', abbr: 'OR' },
    { name: 'Pennsylvania', abbr: 'PA' },
    { name: 'Puerto Rico', abbr: 'PR' },
    { name: 'Rhode Island', abbr: 'RI' },
    { name: 'South Carolina', abbr: 'SC' },
    { name: 'South Dakota', abbr: 'SD' },
    { name: 'Tennessee', abbr: 'TN' },
    { name: 'Texas', abbr: 'TX' },
    { name: 'Utah', abbr: 'UT' },
    { name: 'Vermont', abbr: 'VT' },
    { name: 'Virginia', abbr: 'VA' },
    { name: 'Washington', abbr: 'WA' },
    { name: 'West Virginia', abbr: 'WV' },
    { name: 'Wisconsin', abbr: 'WI' },
    { name: 'Wyoming', abbr: 'WY' }
  ]
  us_id = Country.find_by_iso('US').id
  states.each do |s|
    state = State.create(country_id: us_id, name: s[:name], abbreviation: s[:abbr])
    state.save
  end
end

desc "Seed states"
task :migrate_states => :environment do 
  Location.all.each do |l|
    if l.old_state
      l.state_id = State.where(abbreviation: l.old_state).first.id 
      l.save
    end
  end
  StolenRecord.all.each do |l|
    if l.old_state
      l.state_id = State.where(abbreviation: l.old_state).first.id 
      l.save
    end
  end
end
