class BikeCreatorBuilder
  def initialize(b_param = nil)
    @b_param = b_param
  end

  def verified_bike(bike)
    BikeCreatorVerifier.new(@b_param, bike).verify
  end

  def add_front_wheel_size(bike)
    if bike.rear_wheel_size_id.present? and bike.cycle_type_id == CycleType.find_by_slug("bike").id
      bike.front_wheel_size_id = bike.rear_wheel_size_id
      bike.front_tire_narrow = bike.rear_tire_narrow
    end
  end

  def add_required_attributes(bike)
    unless bike.cycle_type_id.present?
      bike.cycle_type_id = CycleType.find_by_slug("bike").id 
    end
    unless bike.propulsion_type_id.present?
      bike.propulsion_type_id = PropulsionType.find_by_name("Foot pedal").id 
    end    
    bike 
  end

  def new_bike
    bike = Bike.new(@b_param.bike)
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