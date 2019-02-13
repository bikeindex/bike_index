class UserNotLoggedInError < StandardError
end

class BikeUpdatorError < StandardError
end

class BikeUpdator
  def initialize(creation_params = {})
    @user = creation_params[:user] 
    @bike_params = creation_params[:b_params]
    @bike = creation_params[:bike] || find_bike
    @current_ownership = creation_params[:current_ownership]
    @currently_stolen = @bike.stolen
  end

  def find_bike
    begin
      return Bike.unscoped.find(@bike_params['id'])
    rescue
      raise BikeUpdatorError, "Oh no! We couldn't find that bike"
    end
  end

  def update_ownership
    @bike.update_attribute :updator_id, @user.id if @user.present? && @bike.updator_id != @user.id
    if @bike_params['bike'] && @bike_params['bike']['owner_email'] &&
      @bike.owner_email != @bike_params['bike']['owner_email']
      if @bike_params['bike']['owner_email'].blank?
        @bike_params['bike'].delete('owner_email')
      else
        opts = {
          owner_email: @bike_params['bike']['owner_email'],
          bike: @bike,
          creator: @user,
          send_email: true
        }
        OwnershipCreator.new(opts).create_ownership
        @bike_params['bike']['is_for_sale'] = false
      end
    end
  end

  def ensure_ownership!
    return true if @current_ownership && @current_ownership.owner == @user # So we can pass in ownership and skip query
    return true if @user && @bike.owner == @user
    raise BikeUpdatorError, "Oh no! It looks like you don't own that bike."
  end

  def update_api_components
    ComponentCreator.new(bike: @bike, b_param: @bike_params).update_components_from_params
  end

  def update_stolen_record
    @bike.reload
    if @bike_params['bike'] && @bike_params['bike']['date_stolen']
      StolenRecordUpdator.new(bike: @bike, date_stolen: @bike_params['bike']['date_stolen']).update_records
    else
      if @bike_params['stolen_record'] || @bike_params['bike']['stolen_records_attributes']
        StolenRecordUpdator.new(bike: @bike, b_param: @bike_params).update_records
        @bike.reload
      elsif @currently_stolen != @bike.stolen
        StolenRecordUpdator.new(bike: @bike).update_records
      end
    end
  end

  def set_protected_attributes
    @bike_params['bike']['serial_number'] = @bike.serial_number
    @bike_params['bike']['manufacturer_id'] = @bike.manufacturer_id
    @bike_params['bike']['manufacturer_other'] = @bike.manufacturer_other
    @bike_params['bike']['creation_organization_id'] = @bike.creation_organization_id
    @bike_params['bike']['creator'] = @bike.creator
    @bike_params['bike']['example'] = @bike.example
    @bike_params['bike']['hidden'] = @bike.hidden
  end

  def remove_blank_components
    return false unless @bike.components.any?
    @bike.components.each do |c|
      c.destroy unless c.ctype_id.present? || c.description.present? 
    end
  end

  def update_available_attributes
    ensure_ownership!
    set_protected_attributes
    update_ownership
    update_api_components if @bike_params['components'].present?
    update_stolen_record if @bike.update_attributes(@bike_params['bike'].except('stolen_records_attributes'))
    AfterBikeSaveWorker.perform_async(@bike.id) if @bike.present? # run immediately
    remove_blank_components
    @bike
  end

end