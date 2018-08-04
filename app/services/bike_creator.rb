class BikeCreator
  def initialize(b_param = nil)
    @b_param = b_param
    @bike = nil
  end

  def add_bike_book_data
    return nil unless @b_param && @b_param.bike.present? && @b_param.manufacturer_id.present?
    return nil unless @b_param.bike['frame_model'].present? && @b_param.bike['year'].present?
    bb_data = BikeBookIntegration.new.get_model({
      manufacturer: Manufacturer.find(@b_param.bike['manufacturer_id']).name,
      year: @b_param.bike['year'],
      frame_model: @b_param.bike['frame_model']
    })
    return true unless bb_data && bb_data['bike'].present?
    @b_param.params['bike']['cycle_type'] = bb_data['bike']['cycle_type'] if bb_data['bike'] && bb_data['bike']['cycle_type'].present?
    if bb_data['bike']['paint_description'].present?
      @b_param.params['bike']['paint_name'] = bb_data['bike']['paint_description'] unless @b_param.params['bike']['paint_name'].present?
    end
    if bb_data['bike']['description'].present?
      if @b_param.params['bike']['description'].present?
        @b_param.params['bike']['description'] += " #{bb_data['bike']['description']}"
      else
        @b_param.params['bike']['description'] = bb_data['bike']['description']
      end
    end
    @b_param.params['bike']['rear_wheel_bsd'] = bb_data['bike']['rear_wheel_bsd'] if bb_data['bike']['rear_wheel_bsd'].present?
    @b_param.params['bike']['rear_tire_narrow'] = bb_data['bike']['rear_tire_narrow'] if bb_data['bike']['rear_tire_narrow'].present?
    @b_param.params['bike']['stock_photo_url'] = bb_data['bike']['stock_photo_url'] if bb_data['bike']['stock_photo_url'].present?
    @b_param.params['components'] = bb_data['components'] && bb_data['components'].map { |c| c.merge('is_stock' => true) }
    @b_param.clean_params # if we just rely on the before_save filter, @b_param needs to be reloaded
    @b_param.save if @b_param.id.present? 
    @b_param
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

  def validate_record(bike)
    return clear_bike(bike) if bike.errors.present?
    @b_param.find_duplicate_bike(bike) if @b_param.no_duplicate
    if @b_param.created_bike.present?
      clear_bike(bike)
      @bike = @b_param.created_bike
    elsif @b_param.id.present? # Only update b_param if it exists
      @b_param.update_attributes(created_bike_id: bike.id, bike_errors: nil)
    end
    @bike 
  end

  def save_bike(bike)
    bike.save
    @bike = create_associations(bike)
    validate_record(@bike)
    if @bike.present? && @bike.id.present?
      @bike.create_creation_state(creation_state_attributes)
      AfterBikeSaveWorker.perform_async(@bike.id)
      if @b_param.bike_code.present? && @bike.creation_organization.present?
        bike_code = BikeCode.lookup(@b_param.bike_code, organization_id: @bike.creation_organization.id)
        bike_code && bike_code.claim(@bike.creator, @bike.id)
      end
    end
    @bike
  end

  def new_bike
    @bike = build_new_bike
    @bike
  end

  def create_bike
    add_bike_book_data
    @bike = build_bike
    return @bike if @bike.errors.present?
    save_bike(@bike)
  end

  private

  def creation_state_attributes
    {
      is_bulk: @b_param.is_bulk,
      is_pos: @b_param.is_pos,
      is_new: @b_param.is_new,
      origin: @b_param.origin,
      bulk_import_id: @b_param.params["bulk_import_id"],
      creator_id: @b_param.creator_id,
      organization_id: @bike.creation_organization_id
    }
  end
end
