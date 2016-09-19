module BikeSearchable
  extend ActiveSupport::Concern
  module ClassMethods
    def search(interpreted_params)
      matches = interpreted_params[:serial] ? matches.search_matching_serial(interpreted_params[:serial]) : self
      non_serial_matches(interpreted_params, matches)
    end

    def search_close_serials(interpreted_params)
      return nil unless interpreted_params[:serial]
      exact_match_ids = search(interpreted_params).pluck(:id)
      non_serial_matches(interpreted_params, where.not(id: exact_match_ids))
        .search_matching_serials(interpreted_params)
    end

    def selected_query_items(query_params)
      interpreted_params = searchable_interpreted_params(query_params)
      [interpreted_params[:query]] +
        interpreted_params[:manufacturer_ids].map { |id| Manufacturer.friendly_find(id) }
          .compact.map(&:autocomplete_result_hash) + # Ignore manufacturer_ids we don't have
        interpreted_params[:color_ids].map { |id| Color.friendly_find(id) }
          .compact.map(&:autocomplete_result_hash) # Ignore color_ids we don't have
    end

    def searchable_interpreted_params(query_params)
      normalized_serial = SerialNormalizer.new(serial: query_params[:serial]) if query_params[:serial].present?
      (normalized_serial ? { normalized_serial: normalized_serial }  : {}) # serial if present
        .merge(searchable_query_items_query(query_params)) # query if present
        .merge(searchable_query_items_manufacturer_ids(query_params)) # manufacturer if present
        .merge(searchable_query_items_color_ids(query_params)) # color if present
        .merge(searchable_query_stolenness(query_params))
    end

    # Private (internal only) methods below here

    def non_serial_matches(interpreted_params, matches)
      matches = matches.search_matching_stolenness(interpreted_params) if interpreted_params[:stolenness]
      matches = matches.where(manufacturer_id: interpreted_params[:manufacturer_ids]) if interpreted_params[:manufacturer_ids]
      # Because each color can be in any potential spot, search using OR for each color
      interpreted_params[:color_ids] && interpreted_params[:color_ids].each { |c| matches = matches.search_matching_color_ids(c) }
      matches
    end

    def searchable_query_items_query(query_params)
      return { query: query_params[:query] } if query_params[:query].present?
      query = query_params[:query_items] && query_params[:query_items].select { |i| !(/\A[cm]_/ =~ i) }
      query && { query: query.join(' ') } || { } # empty hash unless query is present
    end

    def searchable_query_items_manufacturer_ids(query_params)
      return { manufacturer_ids: query_params[:manufacturer_ids] } if query_params[:manufacturer_ids].present?
      manufacturer_ids = query_params[:query_items] && query_params[:query_items].select { |i| /\Am_/ =~ i }
      return { } unless manufacturer_ids && manufacturer_ids.any?
      { manufacturer_ids: manufacturer_ids.map{ |i| i.gsub(/m_/, '').to_i } }
    end

    def searchable_query_items_color_ids(query_params)
      return { color_ids: query_params[:color_ids] } if query_params[:color_ids].present?
      color_ids = query_params[:query_items] && query_params[:query_items].select { |i| /\Ac_/ =~ i }
      return { } unless color_ids && color_ids.any?
      { color_ids: color_ids.map{ |i| i.gsub(/c_/, '').to_i } }
    end

    def searchable_query_stolenness(query_params)
      return { } unless query_params[:stolenness].present?
      return { stolenness: 'non' } if query_params[:stolenness] == 'non'
      proximity = query_params[:proximity].present? && !(query_params[:proximity] =~ /anywhere/i) && query_params[:proximity]
      return { stolenness: 'stolen' } unless query_params[:stolenness] == 'proximity' && proximity
      distance = query_params[:distance] && query_params[:distance].to_i
      {
        stolenness: 'proximity',
        location: (proximity == 'ip' || proximity == 'you') ? Geocoder.search(proximity) : proximity,
        distance: (distance && distance > 1) ? distance : 100
      }
    end

    # Actual searcher methods

    def search_matching_color_ids(color_ids)
      where(arel_table[:primary_frame_color_id].eq(color_ids)
        .or(arel_table[:secondary_frame_color_id].eq(color_ids))
        .or(arel_table[:tertiary_frame_color_id].eq(color_ids)))
    end

    def search_matching_serial(serial, normalized_serial)
      where('serial_normalized @@ ?', .normalized)
    end

    def search_matching_stolenness(interpreted_params)
      if interpreted_params[:stolenness] == 'non'
        return where(stolen: false)
      elsif interpreted_params[:stolenness] == 'proximity'
        box = Geocoder::Calculations.bounding_box(interpreted_params[:location], interpreted_params[:distance])
        return where(stolen: true).within_bounding_box(box) unless box[0].nan?
      end
      where(stolen: true)
    end

    def search_matching_close_serials()
  end
end
