class BikeSearcher
  def initialize(creation_params = {})
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

  def stolenness
    if @params[:non_stolen].present? || @params[:stolen].present?
      if @params[:stolen].present? && @params[:stolen]
        "stolen"
      elsif @params[:non_stolen].present? && @params[:non_stolen]
        "non_stolen"
      end
    end
  end

  def matching_stolenness(bikes)
    if stolenness == 'stolen'
      @bikes = bikes.stolen 
    elsif stolenness == 'non_stolen'
      @bikes = bikes.non_stolen 
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
    return nil unless @params[:query].present?
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
      manufacturer = Manufacturer.fuzzy_id_or_name_find(@params[:manufacturer])
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
    if @params[:colors].present?
      color_ids = @params[:colors].split(',')
        .collect{ |c| Color.fuzzy_name_find(c).id if Color.fuzzy_name_find(c) }
    elsif @params[:query] && @params[:query].match(/(,?c_\d+)/)
      color_ids = @params[:query].scan(/(,?c_\d+)/).flatten
        .map{ |c| c.gsub(/(,?c_)/,'') }
    end
    if color_ids.present?
      color_ids.compact.each do |c_id|
        @bikes = bikes.where("primary_frame_color_id = ? OR secondary_frame_color_id = ? OR tertiary_frame_color_id = ?", c_id, c_id, c_id)
      end
    end
    @bikes
  end

  def fuzzy_find_serial_ids(bike_ids=[])
    @normer.normalized_segments.each do |seg|
      next unless seg.length > 3
      bike_ids += NormalizedSerialSegment.where("LEVENSHTEIN(segment, ?) < 3", seg).map(&:bike_id)
    end
    bike_ids
  end

  def fuzzy_find_serial
    return nil unless @normer.normalized_segments.present?
    bike_ids = fuzzy_find_serial_ids
    pp bike_ids
    # Don't return exact matches
    bike_ids = bike_ids.uniq - matching_serial.map(&:id)
    Bike.where('id in (?)', bike_ids)
  end    

  def by_proximity
    return nil unless stolenness == 'stolen'
    return nil if @params[:non_proximity] && @params[:non_proximity].present?
    stolen_ids = @bikes.pluck(:current_stolen_record_id)
    return nil unless stolen_ids.present?
    if @params[:proximity_radius].present? && @params[:proximity_radius].to_i > 1
      radius = @params[:proximity_radius].to_i
    end
    radius ||= 500
    box = Geocoder::Calculations.bounding_box(@params[:proximity], radius)
    unless box[0].nan?
      bike_ids = StolenRecord.where('id in (?)', stolen_ids).within_bounding_box(box).pluck(:bike_id)
      @bikes = @bikes.where('id in (?)', bike_ids)
    end
    @bikes
  end

  def by_date
    return nil unless stolenness == 'stolen'
    return @bikes unless @params[:stolen_before].present? || @params[:stolen_after].present?
    stolen_records = StolenRecord.where('id in (?)', @bikes.pluck(:current_stolen_record_id))
    if @params[:stolen_before].present?
      before = Time.at(@params[:stolen_before]).utc.to_datetime
      stolen_records = stolen_records.where("date_stolen <= ?", before)
    end
    if @params[:stolen_after].present?
      after = Time.at(@params[:stolen_after]).utc.to_datetime
      stolen_records = stolen_records.where("date_stolen >= ?", after)
    end
    @bikes = @bikes.where('id in (?)', stolen_records.pluck(:bike_id))
    # @bikes
  end

  def find_bikes
    @bikes = matching_serial 
    matching_stolenness(@bikes)
    matching_manufacturer(@bikes)
    matching_colors(@bikes)
    matching_query(@bikes)
    if stolenness == 'stolen'
      by_proximity
      by_date
    end    
    @bikes
  end

  def find_bike_counts
    @params[:non_stolen] = false
    @params[:non_proximity] = false
    @bikes = matching_serial
    matching_manufacturer(@bikes)
    matching_colors(@bikes)
    matching_query(@bikes)
    result = { non_stolen: @bikes.non_stolen.count }
    if @params[:serial].present?
      result[:close_serials] = fuzzy_find_serial.count
    end
    @params[:stolen] = true
    matching_stolenness(@bikes)
    by_date
    
    result[:stolen] = @bikes.count
    
    by_proximity
    result.merge({proximity: @bikes.count})
  end

  def close_serials
    @bikes = fuzzy_find_serial
    matching_stolenness(@bikes)
    matching_query(@bikes)
    by_proximity
    @bikes
  end

end