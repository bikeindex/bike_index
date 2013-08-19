class BikeSearcher
  def initialize(creation_params = {})
    @params = creation_params
    @bikes = Bike.scoped
  end

  def matching_stolenness(bikes)
    if @params[:non_stolen_included] or @params[:stolen_included]
      @bikes = @bikes.non_stolen unless @params[:stolen_included]
      @bikes = @bikes.stolen unless @params[:non_stolen_included]
    end
    @bikes
  end

  def parsed_attributes
    input = @params[:bike_attribute_ids].to_s
    input = input.gsub(/[^0-9\,]+/,'')
    attribute_ids = input.split(',').reject(&:empty?)
    attributes = ""
    attribute_ids.each do |attribute|
      attributes += "frame_color#{attribute.to_i} "
    end
    attributes
  end

  def parsed_manufacturer_ids
    input = @params[:manufacturer_ids].to_s
    input = input.gsub(/[^0-9\,]+/,'')
    mnfg_ids = input.split(',').reject(&:empty?)
    mnfg_ids.collect! {|m| m.to_i}
    mnfg_ids
  end

  def matching_manufacturers(bikes)
    if @params[:manufacturer_ids]
      @bikes = bikes.where(manufacturer_id: parsed_manufacturer_ids)
    end
    @bikes
  end

  def matching_attributes(bikes)
    if @params[:bike_attribute_ids]
      @bikes = bikes.attributes_search(parsed_attributes)
    end
    @bikes
  end

  def matching_query(bikes)
    if @params[:query]
      @bikes = bikes.text_search(@params[:query])
    end
    @bikes
  end

  def find_bikes
    matching_stolenness(@bikes)
    matching_manufacturers(@bikes)
    matching_attributes(@bikes)
    matching_query(@bikes)
    @bikes
  end

end