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

  def parsed_manufacturer_ids
    if @params[:find_manufacturers]
      mnfg_ids = @params[:find_manufacturers][:ids].reject(&:empty?)
      if mnfg_ids.any?
        mnfg_ids.collect! {|m| m.to_i}
        return mnfg_ids 
      end
      nil
    end
  end

  def matching_manufacturers(bikes)
    if parsed_manufacturer_ids
      @bikes = bikes.where(manufacturer_id: parsed_manufacturer_ids)
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

  def matching_attr_cache(bikes)
    if parsed_attributes
      @bikes = bikes.attr_cache_search(parsed_attributes)
    end
    @bikes
  end

  def matching_query(bikes)
    if @params[:query]
      @bikes = bikes.text_search(@params[:query])
    end
    @bikes
  end
  
  def matching_updated_since(bikes)
    if @params[:updated_since]
      since_date = DateTime.parse(@params[:updated_since])
      @bikes = bikes.where("updated_at >= ?", since_date)
    end
    @bikes
  end

  def find_bikes
    matching_updated_since(@bikes)
    matching_stolenness(@bikes)
    matching_manufacturers(@bikes)
    matching_attr_cache(@bikes)
    matching_query(@bikes)
    @bikes
  end

end