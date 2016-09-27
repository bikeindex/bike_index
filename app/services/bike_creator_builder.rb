class BikeCreatorBuilder
  def initialize(b_param = nil)
    @b_param = b_param
  end

  def verified_bike(bike)
    BikeCreatorVerifier.new(@b_param, bike).verify
  end

  def add_front_wheel_size(bike)
    return true unless bike.rear_wheel_size_id.present?
    return true if bike.front_wheel_size_id.present?
    bike.front_wheel_size_id = bike.rear_wheel_size_id
    bike.front_tire_narrow = bike.rear_tire_narrow
  end

  def add_required_attributes(bike)
    bike.cycle_type_id ||= CycleType.bike.id
    bike.propulsion_type_id ||= PropulsionType.foot_pedal.id
    bike 
  end

  def new_bike
    bike = Bike.new(@b_param.bike.except(*BParam.skipped_bike_attrs))
    bike.b_param_id = @b_param.id
    bike.b_param_id_token = @b_param.id_token
    bike.creator_id = @b_param.creator_id
    bike.updator_id = bike.creator_id
    bike
  end

  def build_new
    bike = verified_bike(new_bike)
    bike = add_required_attributes(bike)
    bike
  end

  def build
    return @b_param.created_bike if @b_param.created_bike.present?
    bike = build_new
    add_front_wheel_size(bike)
    bike
  end
end
