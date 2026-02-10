# Seed test users and 50 bikes for user@example.com on first organization
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.

user_attrs = {
  admin: {name: "admin", email: "admin@example.com", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true, superuser: true},
  member: {name: "member", email: "member@example.com", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  user: {name: "user", email: "user@example.com", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  api_accessor: {name: "Api Accessor", email: "api@example.com", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true},
  example_user: {name: "Example user", email: "example_user@bikeindex.org", password: "pleaseplease12", password_confirmation: "pleaseplease12", terms_of_service: true}
}

user_attrs.values.each do |attributes|
  new_user = User.create attributes
  new_user.confirm(new_user.confirmation_token)
  new_user.save
end

org = Organization.create(name: "Ikes Bike's", website: "", short_name: "Ikes", show_on_map: true)
org.save
organization_role = OrganizationRole.create(organization_id: org.id, user_id: User.find_by_email("member@example.com").id, role: "admin")
organization_role.save
org = Organization.example
org.save
organization_role = OrganizationRole.create(organization_id: org.id, user_id: User.find_by_email("example_user@bikeindex.org").id, role: "member")
organization_role.save
org.save
puts "Users added successfully\n"
@user = User.find_by_email("user@example.com")
@member = User.find_by_email("member@example.com")
@org = Organization.first
manufacturer_ids = Manufacturer.frame_makers.pluck(:id)
if manufacturer_ids.blank?
  puts "Skipping bike seeds (no manufacturers imported yet)"
else
  wheel_size_ids = WheelSize.pluck(:id)
  color_ids = Color.pluck(:id)
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
      creator: @user,
      owner_email: @user.email
    )
    bike.serial_number = (0...10).map { rand(65..90).chr }.join
    bike.creation_organization_id = @org.id
    if bike.save
      ownership = Ownership.new(bike_id: bike.id, creator_id: @member.id, user_id: @user.id, owner_email: @user.email, current: true, skip_email: true)
      unless ownership.save
        puts "\n Ownership error \n #{ownership.errors.messages}"
        raise StandardError
      end
      puts "New bike made by #{bike.manufacturer.name}"
    else
      puts "\n Bike error \n #{bike.errors.messages}"
    end
  end
  Bike.pluck(:id).each { |b| CallbackJob::AfterBikeSaveJob.perform_async(b) }
end
