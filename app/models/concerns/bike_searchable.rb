module BikeSearchable
  extend ActiveSupport::Concern
  module ClassMethods
    # searchable_interpreted_params returns the args for by all other public methods in this class
    # query_params:
    #   query_items: array of select2 query items. Parsed into query, manufacturer_ids and color_ids
    #   serial: serial number to search for
    #   query: full text search string. Overrides query_items if passed explicitly
    #   color_ids: array of colors, friendly found, faster if integers. Overrides query_items if passed explicitly
    #   manufacturer_ids: array of manufacturers, friendly found, faster if integers. Overrides query_items if passed explicitly
    #   stolenness: nil, 'non', 'stolen', 'proximity'
    #   proximity: location. Only for stolenness == 'proximity'. 'ip'/'you' uses IP geocoding to return location string
    #   distance: distance in miles for matches. Only for stolenness == 'proximity'
    def searchable_interpreted_params(query_params, ip:)
      normalized = SerialNormalizer.new(serial: query_params[:serial]) if query_params[:serial].present?
      (normalized ? { normalized_serial: normalized.normalized } : {}) # serial if present
        .merge(searchable_query_items_query(query_params)) # query if present
        .merge(searchable_query_items_manufacturer_ids(query_params)) # manufacturer if present
        .merge(searchable_query_items_color_ids(query_params)) # color if present
        .merge(searchable_query_stolenness(query_params, ip))
    end

    def search(interpreted_params)
      matches = search_matching_serial(interpreted_params)
      non_serial_matches(interpreted_params, matches)
    end

    def search_close_serials(interpreted_params)
      return Bike.where(id: nil) unless interpreted_params[:normalized_serial]
      exact_match_ids = search(interpreted_params).pluck(:id)
      non_serial_matches(interpreted_params, where.not(id: exact_match_ids))
        .search_matching_close_serials(interpreted_params[:normalized_serial])
    end

    def selected_query_items(interpreted_params) # the initial options for the main select search input
      # Ignore manufacturer_ids and color_ids we don't have
      [interpreted_params[:query]] +
        interpreted_params[:manufacturer_ids].map { |id| Manufacturer.friendly_find(id) }
        .compact.map(&:autocomplete_result_hash) +
        interpreted_params[:color_ids].map { |id| Color.friendly_find(id) }
        .compact.map(&:autocomplete_result_hash)
    end

    # Private (internal only) methods below here, as defined at the start

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
      query && { query: query.join(' ') } || {} # empty hash unless query is present
    end

    def searchable_query_items_manufacturer_ids(query_params)
      manufacturer_ids = extracted_query_items_manufacturer_ids(query_params)
      if manufacturer_ids && !manufacturer_ids.is_a?(Integer)
        manufacturer_ids = manufacturer_ids.map do |m_id|
          next m_id.to_i if m_id.is_a?(Integer) || m_id.strip =~ /\A\d*\z/
          Manufacturer.friendly_id_find(m_id)
        end
      end
      manufacturer_ids ? { manufacturer_ids: manufacturer_ids } : {}
    end

    def searchable_query_items_color_ids(query_params)
      color_ids = extracted_query_items_color_ids(query_params)
      if color_ids && !color_ids.is_a?(Integer)
        color_ids = color_ids.map do |c_id|
          next c_id.to_i if c_id.is_a?(Integer) || c_id.strip =~ /\A\d*\z/
          Color.friendly_id_find(c_id)
        end
      end
      color_ids ? { color_ids: color_ids } : {}
    end

    
    def extracted_query_items_manufacturer_ids(query_params)
      return query_params[:manufacturer_ids] if query_params[:manufacturer_ids].present?
      manufacturer_ids = query_params[:query_items] && query_params[:query_items].select { |i| /\Am_/ =~ i }
      return nil unless manufacturer_ids && manufacturer_ids.any?
      manufacturer_ids.map { |i| i.gsub(/m_/, '').to_i }
    end

    def extracted_query_items_color_ids(query_params)
      return query_params[:color_ids] if query_params[:color_ids].present?
      color_ids = query_params[:query_items] && query_params[:query_items].select { |i| /\Ac_/ =~ i }
      return nil unless color_ids && color_ids.any?
      color_ids.map { |i| i.gsub(/c_/, '').to_i }
    end

    def searchable_query_stolenness(query_params, ip)
      return {} unless query_params[:stolenness].present?
      return { stolenness: 'non' } if query_params[:stolenness] == 'non'
      searchable_proximity_hash(query_params, ip) || { stolenness: 'stolen' }
    end

    def searchable_proximity_hash(query_params, ip)
      return false unless query_params[:stolenness] == 'proximity'
      proximity = query_params[:proximity].present? && query_params[:proximity]
      return false unless proximity && !(proximity =~ /anywhere/i)
      distance = query_params[:distance] && query_params[:distance].to_i
      if proximity == 'ip' || proximity == 'you'
        return false unless ip.present?
        proximity = Geocoder.search(ip)
      end
      {
        stolenness: 'proximity',
        location:  proximity,
        distance: (distance && distance > 1) ? distance : 100
      }
    end

    # Actual searcher methods

    def search_matching_color_ids(color_id)
      where(arel_table[:primary_frame_color_id].eq(color_id)
        .or(arel_table[:secondary_frame_color_id].eq(color_id))
        .or(arel_table[:tertiary_frame_color_id].eq(color_id)))
    end

    def search_matching_serial(interpreted_params)
      return self unless interpreted_params[:normalized_serial]
      # Note: @@ is postgres fulltext search
      where('serial_normalized @@ ?', interpreted_params[:normalized_serial])
    end

    def search_matching_stolenness(interpreted_params)
      return where(stolen: false) if interpreted_params[:stolenness] == 'non'
      if interpreted_params[:stolenness] == 'proximity'
        box = Geocoder::Calculations.bounding_box(interpreted_params[:location], interpreted_params[:distance])
        return where(stolen: true).within_bounding_box(box) unless box[0].nan?
      end
      where(stolen: true)
    end

    def search_matching_close_serials(normalized_serial)
      where('LEVENSHTEIN(serial_normalized, ?) < 3', normalized_serial)
    end
  end
end
