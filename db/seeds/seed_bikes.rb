# Seed 50 bikes for user@bikeindex.org on the first organization
@user = User.find_by_email("user@bikeindex.org")
@member = User.find_by_email("member@bikeindex.org")
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
