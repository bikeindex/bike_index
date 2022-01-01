class BikeVersionCreatorWorker < ApplicationWorker
  sidekiq_options retry: false, queue: "high_priority"

  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    bike_version = bike.bike_versions.build(manufacturer: bike.manufacturer,
      mnfg_name: bike.mnfg_name,
      primary_frame_color: bike.primary_frame_color,
      secondary_frame_color: bike.secondary_frame_color,
      tertiary_frame_color: bike.tertiary_frame_color,
      rear_wheel_size: bike.rear_wheel_size,
      front_wheel_size: bike.front_wheel_size,
      rear_gear_type: bike.rear_gear_type,
      front_gear_type: bike.front_gear_type,
      owner_id: bike.owner.id)
    bike_version.save
  end
end
