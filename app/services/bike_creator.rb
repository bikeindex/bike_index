class BikeCreatorError < StandardError
end

class BikeCreator
  def initialize(b_param = nil)
    @b_param = b_param
    @bike = nil
  end

  def build_new_bike
    @bike = BikeCreatorBuilder.new(@b_param).build_new
  end

  def build_bike
    @bike = BikeCreatorBuilder.new(@b_param).build 
  end

  def create_associations(bike)
    @bike = BikeCreatorAssociator.new(@b_param).associate(bike)
  end

  def clear_bike(bike)
    build_bike
    bike.errors.messages.each do |message|
      @bike.errors.add(message[0], message[1][0])
    end
    bike.destroy
    @bike
  end

  # def associate_picture_with_params
  #   # I think this might be required, check it
  #   # BikeCreatorAssociator.new(@b_param).associate_picture(@b_param)
  # end

  def validate_record(bike)
    if bike.errors.present?
      clear_bike(bike)
    elsif @b_param.created_bike.present?
      bike.destroy
      @bike = @b_param.created_bike
    else
      @b_param.update_attributes(created_bike_id: bike.id, bike_errors: nil)
    end
    @bike 
  end

  def save_bike(bike)
    bike.save
    @bike = create_associations(bike)
    validate_record(@bike)
    @bike
  end

  def new_bike
    @bike = build_new_bike
    @bike
  end

  def create_bike
    @bike = build_bike
    return @bike if @bike.errors.present?
    return @bike if @bike.payment_required
    save_bike(@bike)
  end

  def create_paid_bike
    @bike = build_bike
    @bike.payment_required = false
    @bike.verified = true
    @bike.paid_for = true
    save_bike(@bike)
  end

end