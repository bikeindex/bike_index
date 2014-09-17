class BikeSearcher
  def initialize(creation_params = {},approved=nil)
    @approved = approved
    @params = creation_params
    @bikes = Bike.scoped
    if @params[:search_type].present?
      if @params[:search_type] == 'serial'
        @params[:serial] = @params[:query_typed]
      else
        @params[:query] = @params[:query_typed]
      end
    end
    if @params[:serial].present?
      if @params[:query].present?
        @params[:query] = @params[:query].gsub(/,?#,?/,'')
      end
      @normer = SerialNormalizer.new(serial: @params[:serial])
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
    return bikes unless @params[:query].present?     
    @bikes = bikes.text_search(@params[:query].gsub(/(,?c_\d+|,?m_\d+)/,''))
    @bikes
  end

  def matching_serial
    if @params[:serial].present?
      @bikes = Bike.where("serial_normalized @@ ?", @normer.normalized)
    end
    @bikes
  end

  def matching_manufacturer(bikes)
    if @params[:manufacturer].present?
      manufacturer = Manufacturer.fuzzy_name_find(@params[:manufacturer])
      if manufacturer.present?
        @params[:manufacturer_id] = manufacturer.id 
      else
        @params[:manufacturer_id] = 0
      end
    end
    if @params[:query] && @params[:query].match(/(,?m_\d+)/)
      @params[:manufacturer_id] = @params[:query].match(/(,?m_\d+)/)[0].gsub(/,?m_/,'') 
    end
    @bikes = bikes.where(manufacturer_id: @params[:manufacturer_id]) if @params[:manufacturer_id].present?
    @bikes
  end

  def matching_colors(bikes)
    if @params[:query] && @params[:query].match(/(,?c_\d+)/)
      @params[:query].scan(/(,?c_\d+)/).flatten.each do |c|
        c_id = c.gsub(/(,?c_)/,'')
        bikes = bikes.where("primary_frame_color_id = ? OR secondary_frame_color_id = ? OR tertiary_frame_color_id = ?", c_id, c_id, c_id)
      end
      @bikes = bikes
    end
    @bikes
  end

  def fuzzy_find_serial
    return nil unless @normer.normalized_segments.present?
    bike_ids = []
    @normer.normalized_segments.each do |seg|
      next unless seg.length > 3
      bike_ids += NormalizedSerialSegment.where("LEVENSHTEIN(segment, ?) < 3", seg).map(&:bike_id)
    end
    # Don't return exact matches
    bike_ids = bike_ids.uniq - matching_serial.map(&:id)
    Bike.where('id in (?)', bike_ids)
  end    

  def by_proximity
    proximity = 500
    proximity = @params[:proximity_radius] if @params[:proximity_radius].present? && @params[:proximity_radius].strip.length > 0
    stolen_ids = @bikes.pluck(:current_stolen_record_id)
    box = Geocoder::Calculations.bounding_box(@params[:proximity], proximity)
    bike_ids = StolenRecord.where('id in (?)', stolen_ids).within_bounding_box(box).pluck(:bike_id)
    @bikes = @bikes.where('id in (?)', bike_ids)
  end

  def find_bikes
    if @params[:stolen].present? or @params[:query].present? or @params[:serial].present? or @params[:manufacturer_id].present? or @params[:manufacturer].present?
      @bikes = matching_serial 
      matching_stolenness(@bikes)
      matching_manufacturer(@bikes)
      matching_colors(@bikes)
      matching_query(@bikes)
      by_proximity if @params[:stolen] && @params[:proximity].present? && @params[:proximity].strip.length > 1
    else
      @bikes = Bike.where(stolen: false).order("RANDOM()")
    end
    @bikes.limit(500)
  end

  def close_serials
    @bikes = fuzzy_find_serial
    matching_stolenness(@bikes)
    matching_query(@bikes)
    by_proximity if @params[:stolen] && @params[:proximity].present? && @params[:proximity].strip.length > 1
    @bikes
  end

end