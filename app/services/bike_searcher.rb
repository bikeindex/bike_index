class BikeSearcher
  def initialize(creation_params = {})
    @params = creation_params
    @bikes = Bike.scoped
    if @params[:serial].present?
      @normed_ser = SerialNormalizer.new(serial: @params[:serial]).normalized
    end
  end

  def matching_stolenness(bikes)
    if @params[:non_stolen] or @params[:stolen]
      @bikes = bikes.non_stolen unless @params[:stolen]
      @bikes = bikes.stolen unless @params[:non_stolen]
    end
    @bikes 
  end

  def parsed_attributes
    if @params[:find_bike_attributes]
      attr_ids = @params[:find_bike_attributes][:ids].reject(&:empty?)
      return attr_ids  if attr_ids.any?
      nil
    end
  end

  def matching_query(bikes)
    if @params[:query]
      @bikes = bikes.text_search(@params[:query])
    end
    @bikes
  end

  def matching_serial
    if @params[:serial].present?
      @bikes = Bike.where(serial_normalized: @normed_ser)
    end
    @bikes
  end

  def fuzzy_find_serial
    if @normed_ser.present?
      Bike.where("LEVENSHTEIN(serial_normalized, ?) < 3", @normed_ser)
    end
  end    
  
  def find_bikes
    @bikes = matching_serial    
    matching_stolenness(@bikes)
    matching_query(@bikes)
    @bikes
  end

end