class BikeSearcher
  def initialize(creation_params = {}, reverse_geocode = nil)
    # override reverse_geocode if passed as params
    @params = creation_params.merge(reverse_geocode: reverse_geocode)
    @bikes = params[:api_search] ? Bike.non_recovered : Bike.all
    if @params[:search_type].present?
      if @params[:search_type] == 'serial'
        @params[:serial] = @params[:query_typed]
      else
        @params[:query] = @params[:query_typed]
      end
    end
    @params = interpreted_params(@params)
    if @params[:serial].present?
      if @params[:query].present?
        @params[:query] = @params[:query].gsub(/,?#,?/,'')
      end
      @normer = SerialNormalizer.new(serial: @params[:serial])
    end
  end

  attr_accessor :params, :location

  def interpreted_params(i_params)
    query = (i_params[:query] || '').gsub('%23', '#') # ... ensure string so we can gsub it
    return i_params unless query.present?
    # serial segment looks like s#SERIAL#
    serial_matcher = /s#[^#]*#/i
    query.gsub!(serial_matcher) do |match|
      # Set the serial to the match, with the first part chopped and the last part chopped
      i_params[:serial] = match.gsub(/\As#/, '').gsub(/#\z/, '')
      '' # remove it from query
    end
    i_params.merge(query: query)
  end

  # Remove the encoding tricks we use with selectize
  def stripped_query
    @params[:query]
      .gsub(/m_\d+/, '') # manufacturers
      .gsub(/c_\d+/, '') # colors
      .gsub(/%2C/i, ',') # unencode commas
  end

  def selectize_items
    items = []
    if @params[:manufacturer_id].present?
      items << Manufacturer.find(@params[:manufacturer_id]).autocomplete_result_hash
    end
    if @color_ids.present?
      @color_ids.each { |c_id| items << Color.find(c_id).autocomplete_result_hash }
    end
    if @params[:serial].present?
      items << { id: 'serial', search_id: "s##{@params[:serial]}#", text: @params[:serial] }.as_json
    end
    if @params[:query]
      stripped_query.split(',').reject(&:blank?)
        .each { |q| items << { search_id: q, text: q }.as_json }
    end
    items
  end

  def stolenness
    return nil unless @params[:non_stolen].present? || @params[:stolen].present?
    return 'stolen' if @params[:stolen].present? && @params[:stolen]
    return 'non_stolen' if @params[:non_stolen].present? && @params[:non_stolen]
  end

  def is_proximity
    return false if @params[:non_proximity] && @params[:non_proximity].present?
    params[:proximity].present?
  end

  def stolenness_type
    return 'all' unless stolenness.present?
    return 'stolen_proximity' if stolenness == 'stolen' && is_proximity
    stolenness
  end

  def matching_stolenness(bikes)
    return @bikes unless stolenness.present?
    @bikes = (stolenness == 'stolen') ? bikes.stolen : bikes.non_stolen
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
    @bikes = bikes.text_search(stripped_query.gsub(',', ' '))
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
      manufacturer = Manufacturer.friendly_find(@params[:manufacturer])
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
      @color_ids = @params[:colors].split(',')
        .collect{ |c| Color.friendly_find(c).id if Color.friendly_find(c) }
    elsif @params[:query] && @params[:query].match(/(,?c_\d+)/)
      @color_ids = @params[:query].scan(/(,?c_\d+)/).flatten
        .map{ |c| c.gsub(/(,?c_)/,'') }
    end
    if @color_ids.present?
      @color_ids.compact.each do |c_id|
        @bikes = bikes.where('primary_frame_color_id = ? OR secondary_frame_color_id = ? OR tertiary_frame_color_id = ?', c_id, c_id, c_id)
      end
    end
    @bikes
  end

  def fuzzy_find_serial_ids(bike_ids=[])
    @normer.normalized_segments.each do |seg|
      next unless seg.length > 3
      bike_ids += NormalizedSerialSegment.where('LEVENSHTEIN(segment, ?) < 3', seg).map(&:bike_id)
    end
    bike_ids
  end

  def fuzzy_find_serial
    return nil unless @normer.normalized_segments.present?
    bike_ids = fuzzy_find_serial_ids
    # Don't return exact matches
    bike_ids = bike_ids.uniq - matching_serial.map(&:id)
    Bike.where('id in (?)', bike_ids)
  end    

  def by_proximity
    return unless is_proximity
    stolen_ids = @bikes.pluck(:current_stolen_record_id)
    return unless stolen_ids.present?
    if @params[:proximity_radius].present? && @params[:proximity_radius].to_i > 1
      radius = @params[:proximity_radius].to_i
    end
    radius ||= 100
    @location = Geocoder.search(@params[:proximity]) if @params[:reverse_geocode]
    box = Geocoder::Calculations.bounding_box((@location || @params[:proximity]), radius)
    unless box[0].nan?
      bike_ids = StolenRecord.where('id in (?)', stolen_ids).within_bounding_box(box).pluck(:bike_id)
      @bikes = @bikes.where('id in (?)', bike_ids)
    end
    @bikes
  end

  def by_date
    return unless stolenness == 'stolen'
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
    result.merge(proximity: @bikes.count)
  end

  def close_serials
    @bikes = fuzzy_find_serial
    matching_stolenness(@bikes)
    matching_query(@bikes)
    by_proximity
    @bikes
  end
end
