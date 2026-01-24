class BikeVersionCreatorJob < ApplicationJob
  sidekiq_options retry: false, queue: "high_priority"

  def perform(bike_id, owner_id = nil)
    bike = Bike.unscoped.find_by_id(bike_id)
    owner_id ||= bike.owner
    bike_version = bike.bike_versions.build(owner_id:,
      frame_model: bike.frame_model,
      cycle_type: bike.cycle_type,
      handlebar_type: bike.handlebar_type,
      propulsion_type: bike.propulsion_type,
      number_of_seats: bike.number_of_seats,

      name: version_name_for(bike),
      description: bike.description,

      primary_frame_color_id: bike.primary_frame_color_id,
      secondary_frame_color_id: bike.secondary_frame_color_id,
      tertiary_frame_color_id: bike.tertiary_frame_color_id,
      paint_id: bike.paint_id,

      front_wheel_size_id: bike.front_wheel_size_id,
      front_tire_narrow: bike.front_tire_narrow,
      rear_wheel_size_id: bike.rear_wheel_size_id,
      rear_tire_narrow: bike.rear_tire_narrow,

      rear_gear_type_id: bike.rear_gear_type_id,
      front_gear_type_id: bike.front_gear_type_id,
      belt_drive: bike.belt_drive,
      coaster_brake: bike.coaster_brake)

    bike.components.each do |c|
      bike_version.components.build(c.version_duplicated_attrs)
    end

    bike_version.save

    bike.public_images.each do |public_image|
      next if bike_version.public_images.where(external_image_url: public_image.image_url).present?

      bike_version.public_images.create(name: public_image.name,
        external_image_url: public_image.image_url)
    end

    bike_version # Needs to return bike version because it is run inline
  end

  private

  def version_name_for(bike)
    version_number = bike.bike_versions.where(owner_id: bike.user&.id).count + 1
    [
      bike.name,
      "Version #{version_number}"
    ].reject(&:blank?).join(", ")
  end
end
