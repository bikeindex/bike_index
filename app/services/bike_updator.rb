class UserNotLoggedInError < StandardError
end

class BikeUpdatorError < StandardError
end


class BikeUpdator
  def initialize(creation_params = nil)
    @user = creation_params[:user] 
    @bike_params = creation_params[:b_params]
    @bike = find_bike
  end

  def find_bike
    begin
    return Bike.find(@bike_params[:id])
    rescue
      raise BikeUpdatorError, "Oh no! We couldn't find that bike"
    end
  end

  def update_ownership
    if @bike_params[:bike] and @bike_params[:bike][:owner_email]
      unless @bike.owner_email == @bike_params[:bike][:owner_email]
        owner_email = @bike_params[:bike][:owner_email]
        OwnershipCreator.new(bike: @bike, owner_email: owner_email, creator: @user).create_ownership
      end
    end
  end

  def ensure_ownership!
    return true if @bike.owner == @user
    raise BikeUpdatorError, "Oh no! It looks like you don't own that bike."
  end

  def update_stolen_record
    if @bike_params[:bike] and @bike_params[:bike][:date_stolen_input]
      StolenRecordUpdator.new(bike: @bike.reload, date_stolen_input: @bike_params[:bike][:date_stolen_input]).update_records
    else
      StolenRecordUpdator.new(bike: @bike.reload).update_records
    end
  end

  def set_protected_attributes
    @bike_params[:bike][:serial_number] = @bike.serial_number
    @bike_params[:bike][:manufacturer_id] = @bike.manufacturer_id
    @bike_params[:bike][:manufacturer_other] = @bike.manufacturer_other
    @bike_params[:bike][:creation_organization_id] = @bike.creation_organization_id
    @bike_params[:bike][:creator] = @bike.creator
    @bike_params[:bike][:verified] = @bike.verified
    # If the bike isn't verified, it can't be marked un-stolen :(
    @bike_params[:bike][:stolen] = @bike.stolen unless @bike.verified?
  end

  def remove_blank_components
    return false unless @bike.components.any?
    @bike.components.each do |c|
      c.destroy unless c.ctype.present? or c.description.present?
    end
  end

  def update_available_attributes
    ensure_ownership!
    set_protected_attributes
    update_ownership
    update_stolen_record if @bike.update_attributes(@bike_params[:bike])
    remove_blank_components
    @bike
  end

end