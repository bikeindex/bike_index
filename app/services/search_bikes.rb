class SearchBikes
  def initialize(params = nil)
    if params.present?
      @query = params[:query] ? params[:query] : nil
      @stolen = params[:search_stolen] ? params[:search_stolen][0] : nil
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

    if @query.present?
      bikes = bikes.text_search(@query)
    end
    
    return bikes 
  end

end