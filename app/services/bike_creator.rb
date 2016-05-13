class BikeCreatorError < StandardError
end

class BikeCreator
  def initialize(bikeParam = nil)
    @bikeParam = bikeParam
    @bike = nil
  end

  def add_bike_book_data
    return nil unless @bikeParam.present? && @bikeParam.params.present? && @bikeParam.params[:bike].present?
    return nil unless @bikeParam.bike[:manufacturer_id].present?
    return nil unless @bikeParam.bike[:frame_model].present?
    return nil unless @bikeParam.bike[:year].present?
    bike = {
      manufacturer: Manufacturer.find(@bikeParam.bike[:manufacturer_id]).name,
      year: @bikeParam.bike[:year],
      frame_model: @bikeParam.bike[:frame_model]
    }
    bb_data = BikeBookIntegration.new.get_model(bike)
    return true unless bb_data.present?
    @bikeParam.params[:bike][:cycle_type] = bb_data[:bike][:cycle_type] if bb_data[:bike][:cycle_type].present?
    if bb_data[:bike][:paint_description].present?
      @bikeParam.params[:bike][:paint_name] = bb_data[:bike][:paint_description] unless @bikeParam.params[:bike][:paint_name].present?
    end
    if bb_data[:bike][:description].present?
      if @bikeParam.params[:bike][:description].present?
        @bikeParam.params[:bike][:description] += " #{bb_data[:bike][:description]}"
      else
        @bikeParam.params[:bike][:description] = bb_data[:bike][:description]
      end
    end
    @bikeParam.params[:bike][:rear_wheel_bsd] = bb_data[:bike][:rear_wheel_bsd] if bb_data[:bike][:rear_wheel_bsd].present?
    @bikeParam.params[:bike][:rear_tire_narrow] = bb_data[:bike][:rear_tire_narrow] if bb_data[:bike][:rear_tire_narrow].present?
    @bikeParam.params[:bike][:stock_photo_url] = bb_data[:bike][:stock_photo_url] if bb_data[:bike][:stock_photo_url].present?
    @bikeParam.params[:components] = bb_data[:components] && bb_data[:components].map { |c| c.merge(is_stock: true) }
    @bikeParam.id.present? ? @bikeParam.save : @bikeParam.clean_params
    @bikeParam
  end

  def build_new_bike
    @bike = BikeCreatorBuilder.new(@bikeParam).build_new
  end

  def build_bike
    @bike = BikeCreatorBuilder.new(@bikeParam).build 
  end

  def create_associations(bike)
    @bike = BikeCreatorAssociator.new(@bikeParam).associate(bike)
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
  #   # BikeCreatorAssociator.new(@bikeParam).associate_picture(@bikeParam)
  # end

  def validate_record(bike)
    if bike.errors.present?
      clear_bike(bike)
    elsif @bikeParam.created_bike.present?
      bike.destroy
      @bike = @bikeParam.created_bike
    elsif @bikeParam.id.present? # Only update bikeParam if it exists
      @bikeParam.update_attributes(created_bike_id: bike.id, bike_errors: nil)
    end
    @bike 
  end

  def save_bike(bike)
    bike.save
    @bike = create_associations(bike)
    validate_record(@bike)
    if @bike.present?
      ListingOrderWorker.perform_async(@bike.id)
      ListingOrderWorker.perform_in(10.seconds, @bike.id)
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
end
