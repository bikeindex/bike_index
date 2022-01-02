class BikeVersionCreatorWorker < ApplicationWorker
  sidekiq_options retry: false, queue: "high_priority"

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    bike_version = bike.bike_versions.build(owner_id: bike.owner.id,
      manufacturer_id: bike.manufacturer_id,
      mnfg_name: bike.mnfg_name,

      year: bike.year,
      frame_model: bike.frame_model,
      cycle_type: bike.cycle_type,
      handlebar_type: bike.handlebar_type,
      propulsion_type: bike.propulsion_type,
      frame_material: bike.frame_material,
      number_of_seats: bike.number_of_seats,
      name: bike.name,
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
    bike_version.save
  end
end
