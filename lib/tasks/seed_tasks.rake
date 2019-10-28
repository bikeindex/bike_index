# Seed the database with test things!
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.

desc "Seed test users & 50 text bikes for user@example on first organization"
task seed_test_users_and_bikes: :environment do
  user_attrs = {
    admin: { name: "admin", email: "admin@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true, superuser: true },
    member: { name: "member", email: "member@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true },
    user: { name: "user", email: "user@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true },
    api_accessor: { name: "Api Accessor", email: "api@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true },
    example_user: { name: "Example user", email: "example_user@bikeindex.org", password: "please12", password_confirmation: "please12", terms_of_service: true },
  }

  user_attrs.values.each do |attributes|
    new_user = User.create attributes
    new_user.confirm(new_user.confirmation_token)
    new_user.save
  end

  org = Organization.create(name: "Ikes Bike's", website: "", short_name: "Ikes", show_on_map: true)
  org.save
  membership = Membership.create(organization_id: org.id, user_id: User.find_by_email("member@example.com").id, role: "admin")
  membership.save
  org = Organization.create(name: "Example organization", website: "", short_name: "Example org", show_on_map: false, access_token: "7fb1c38526e57a98ec57760aa7f84992")
  org.save
  membership = Membership.create(organization_id: org.id, user_id: User.find_by_email("example_user@bikeindex.org").id, role: "member")
  membership.save
  org.save
  puts "Users added successfully\n"
  @user = User.find_by_email("user@example.com")
  @member = User.find_by_email("member@example.com")
  @org = Organization.first
  50.times do
    bike = Bike.new(
      cycle_type: :bike,
      propulsion_type: "foot-pedal",
      manufacturer_id: (rand(Manufacturer.frame_makers.count) - 1),
      rear_tire_narrow: true,
      handlebar_type: HandlebarType.slugs.first,
      rear_wheel_size_id: (rand(WheelSize.count) - 1),
      front_wheel_size_id: (rand(WheelSize.count) - 1),
      primary_frame_color_id: (rand(Color.count) - 1),
      creator: @user,
      owner_email: @user.email,
    )
    bike.serial_number = (0...10).map { (65 + rand(26)).chr }.join
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
  Bike.pluck(:id).each { |b| AfterBikeSaveWorker.perform_async(b) }
  AutocompleteLoader.new.reset
end

task seed_dup_bikes: :environment do
  @user = User.find_by_email("user@example.com")
  @member = User.find_by_email("member@example.com")
  @org = Organization.first
  @cycle_type = CycleType.new(:bike)
  @serial_number = (0...10).map { (65 + rand(26)).chr }.join
  @manufacturer_id = (rand(Manufacturer.frame_makers.count) + 1)
  500.times do
    bike = Bike.new(
      cycle_type: :bike,
      propulsion_type: "foot-pedal",
      manufacturer_id: @manufacturer_id,
      rear_tire_narrow: true,
      rear_wheel_size_id: WheelSize.first.id,
      primary_frame_color_id: Color.first.id,
      handlebar_type: HandlebarType.slugs.first,
      creator: @user,
      owner_email: @user.email,
      serial_number: @serial_number,
      creation_organization_id: @org.id,
    )
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

namespace :dev do
  desc "Seed Redis with dummy values retrieved by Counts module"
  task seed_counts: :environment do
    next unless Rails.env.development?

    entries = {
      stolen_bikes: 66_406,
      total_bikes: 241_945,
      organizations: 724,
      recoveries: 5_734,
      recoveries_value: 8_188_294,
      week_creation_chart: {
        "2019-06-21": 261,
        "2019-06-22": 323,
        "2019-06-23": 313,
        "2019-06-24": 228,
        "2019-06-25": 226,
        "2019-06-26": 259,
        "2019-06-27": 127,
      }.to_json,
    }

    printf "Assigning Counts values... "
    entries.each_pair { |key, value| Counts.assign_for(key, value) }
    printf "done.\n\n"
    entries.keys.each { |key| puts "Counts.#{key}: #{Counts.public_send(key)}" }
  end
end
