class BikeCreatorBuilder
  def initialize(bikeParam = nil)
    @bikeParam = bikeParam
  end

  def verified_bike(bike)
    BikeCreatorVerifier.new(@bikeParam, bike).verify
  end

  def add_front_wheel_size(bike)
    if bike.rear_wheel_size_id.present? and bike.cycle_type_id == CycleType.bike.id
      bike.front_wheel_size_id = bike.rear_wheel_size_id
      bike.front_tire_narrow = bike.rear_tire_narrow
    end
  end

  def add_required_attributes(bike)
    unless bike.cycle_type_id.present?
      bike.cycle_type_id = CycleType.bike.id 
    end
    unless bike.propulsion_type_id.present?
      bike.propulsion_type_id = PropulsionType.foot_pedal.id
    end    
    bike 
  end

  def new_bike
    bike = Bike.new(@bikeParam.bike)
    bike.bikeParam_id = @bikeParam.id
    bike.bikeParam_id_token = @bikeParam.id_token
    bike.creator_id = @bikeParam.creator_id 
    bike.updator_id = bike.creator_id
    bike
  end

  def build_new
    bike = verified_bike(new_bike)
    bike = add_required_attributes(bike)
    bike
  end

  def build
    return @bikeParam.created_bike if @bikeParam.created_bike.present?
    bike = build_new
    add_front_wheel_size(bike)
    bike
  end

end