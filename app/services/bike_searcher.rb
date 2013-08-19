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

  def parsed_attribute_ids
    if @params[:find_bike_attributes]
      attr_ids = @params[:find_bike_attributes][:ids].reject(&:empty?)
      if attr_ids.any?
        attr_ids.collect! {|m| m.to_i}
        return attr_ids 
      end
      nil
    end
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

  def matching_attributes(bikes)
    if parsed_attribute_ids
      @bikes = bikes.where(primary_frame_color_id: parsed_attribute_ids)
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
    # puts "\n\n\n\n\n\nBIKE COUNT: #{@bikes.count} \n\n\n"
    matching_stolenness(@bikes)
    # puts "\n\n\n\n\n\nBIKE COUNT: #{@bikes.count} \n\n\n"
    matching_manufacturers(@bikes)
    # puts "\n\n\n\n\n\nBIKE COUNT: #{@bikes.count} \n\n\n"
    matching_attributes(@bikes)
    # puts "\n\n\n\n\n\nBIKE COUNT: #{@bikes.count} \n\n\n"
    matching_query(@bikes)
    # puts "\n\n\n\n\n\nBIKE COUNT: #{@bikes.count} \n\n\n"
    @bikes
  end

end