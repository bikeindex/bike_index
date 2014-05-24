class BikeCreatorAssociator
  def initialize(b_param = nil)
    @b_param = b_param
  end

  def create_ownership(bike)
    send_email = true
    if @b_param.params[:bike][:send_email] == false
      send_email = false
    elsif @b_param.params[:bike][:send_email][/false/i]
      send_email = false
    end
    OwnershipCreator.new(bike: bike, creator: @b_param.creator, send_email: send_email).create_ownership
  end

  def create_components(bike)
    ComponentCreator.new(bike: bike, b_param: @b_param).create_components_from_params
  end

  def create_stolen_record(bike)
    StolenRecordUpdator.new(bike: bike, user: @b_param.creator, new_bike_b_param: @b_param).create_new_record
    StolenRecordUpdator.new(bike: bike).set_creation_organization if bike.creation_organization.present?
  end

  def create_normalized_serial_segments(bike)
    SerialNormalizer.new({serial: bike.serial_number}).save_segments(bike.id)
  end

  def update_bike_token(bike)
    if @b_param.bike_token_id.present?
      bike_token = BikeToken.find(@b_param.bike_token_id)
      bike_token.bike_id = bike.id
      return true if bike_token.save
    end
  end

  def attach_photo(bike)
    return true unless @b_param.image.present?
    public_image = PublicImage.new(image: @b_param.image)
    public_image.imageable = bike
    public_image.save
    @b_param.update_attributes(image_processed: true)
    bike.reload
  end

  def associate(bike)
    begin 
      create_ownership(bike)
      create_components(bike)
      create_normalized_serial_segments(bike)
      create_stolen_record(bike) if bike.stolen
      update_bike_token(bike) if bike.created_with_token
      attach_photo(bike)
    rescue => e
      bike.errors.add(:association_error, e.message)
    end
    bike
  end

end