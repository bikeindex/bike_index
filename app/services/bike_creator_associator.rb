class BikeCreatorAssociator
  def initialize(b_param = nil)
    @b_param = b_param
  end

  def create_ownership(bike)
    OwnershipCreator.new(bike: bike, creator: @b_param.creator).create_ownership
  end

  def create_stolen_record(bike)
    StolenRecordUpdator.new(bike: bike, user: @b_param.creator, new_bike_b_param: @b_param).create_new_record
    StolenRecordUpdator.new(bike: bike).set_creation_organization if bike.creation_organization.present?
  end

  def update_bike_token(bike)
    if @b_param.bike_token_id.present?
      bike_token = BikeToken.find(@b_param.bike_token_id)
      bike_token.bike_id = bike.id
      return true if bike_token.save
    end
  end

  # def add_uploaded_image(bike)
  #   if @b_param.params[:bike][:bike_image]
  #     public_image = PublicImage.new(image: @b_param.params[:bike][:bike_image])
  #     public_image.imageable = bike
  #     public_image.save
  #   end
  # end

  def associate(bike)
    begin 
      create_ownership(bike)
      create_stolen_record(bike) if bike.stolen
      update_bike_token(bike) if bike.created_with_token
      # pp bike
    rescue => e
      bike.errors.add(:association_error, e.message)
    end
    # pp bike.errors.messages
    bike
  end

end