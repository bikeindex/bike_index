class SearchBikes
  def initialize(creation_params = {})
    if creation_params.present?
      @query = creation_params[:query]
      @manufacturer_id = creation_params[:manufacturer_id]
      @color_id = creation_params[:color_id]
      @stolen = creation_params[:search_stolen]
    else
      @query, @stolen = nil
    end
  end

  def search_type
    type = {most_recent: false, phrase: ""}
    unless @query.present?
      type[:most_recent] = true
    end
    if @stolen == nil 
      type[:phrase] = "bikes"
    elsif @stolen == "true"
      type[:phrase] = "stolen bikes"
    elsif @stolen == "false"
      type[:phrase] = "non-stolen bikes"
    end
    return type
  end

  def bikes
    # TODO: Is it okay to default scope this?
    # How do I limit the results for most recent?
    bikes = Bike.scoped
    unless @stolen == nil
      if @stolen == "true"
        bikes = bikes.stolen
      elsif @stolen == "false"
        bikes = bikes.non_stolen
      end
    end

    if @color_id
      bikes = bikes.where(primary_frame_color_id: @color_id)
    end

    if @manufacturer_id
      bikes = bikes.where(manufacturer_id: @manufacturer_id)
    end

    if @query.present?
      bikes = bikes.text_search(@query)
    end
    
    return bikes 
  end

end