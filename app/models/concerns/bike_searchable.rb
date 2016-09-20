module BikeSearchable
  extend ActiveSupport::Concern
  module ClassMethods
    # searchable_interpreted_params returns the args for by all other public methods in this class
    # query_params:
    #   query_items: array of select2 query items. Parsed into query, manufacturer_id and color_ids
    #   serial: required for search_close_serials
    #   query: full text search string. Overrides query_items if passed explicitly
    #   colors: array of colors, friendly found, faster if integers. Overrides query_items if passed explicitly
    #   manufacturer: friendly found, faster if integer. Overrides query_items if passed explicitly.
    #   stolenness: can be 'all', 'non', 'stolen', 'proximity'. Defaults to 'stolen'
    #   location: location for proximity search. Only for stolenness == 'proximity'. 'ip'/'you' uses IP geocoding and returns location object
    #   distance: distance in miles for matches. Only for stolenness == 'proximity'
    def searchable_interpreted_params(query_params, ip:)
      normalized = SerialNormalizer.new(serial: query_params[:serial]) if query_params[:serial].present?
      (normalized ? { normalized_serial: normalized.normalized } : {}) # serial if present
        .merge(searchable_query_items_query(query_params)) # query if present
        .merge(searchable_query_items_manufacturer_id(query_params)) # manufacturer if present
        .merge(searchable_query_items_color_ids(query_params)) # color if present
        .merge(searchable_query_stolenness(query_params, ip))
    end

    def search(interpreted_params)
      matches = search_matching_serial(interpreted_params)
      non_serial_matches(interpreted_params, matches)
    end

    def search_close_serials(interpreted_params)
      return nil unless interpreted_params[:normalized_serial]
      exact_match_ids = search(interpreted_params).pluck(:id)
      non_serial_matches(interpreted_params, where.not(id: exact_match_ids))
        .search_matching_close_serials(interpreted_params[:normalized_serial])
    end

    # the initial options for the main select search input
    def selected_query_items_options(interpreted_params)
      # Ignore manufacturer_id and color_ids we don't have
      items = interpreted_params[:query] && [interpreted_params[:query]] || []
      items += [interpreted_params[:manufacturer_id]].flatten.map { |id| Manufacturer.friendly_find(id) }
                 .compact.map(&:autocomplete_result_hash) if interpreted_params[:manufacturer_id]
      items += interpreted_params[:color_ids].map { |id| Color.friendly_find(id) }
                 .compact.map(&:autocomplete_result_hash) if interpreted_params[:color_ids]
      items.flatten.compact
    end

    # Private (internal only) methods below here, as defined at the start

    def non_serial_matches(interpreted_params, matches)
      matches = matches.search_matching_stolenness(interpreted_params) if interpreted_params[:stolenness]
      matches = matches.where(manufacturer_id: interpreted_params[:manufacturer_id]) if interpreted_params[:manufacturer_id]
      # Because each color can be in any potential spot, search using OR for each color
      interpreted_params[:color_ids] && interpreted_params[:color_ids].each { |c| matches = matches.search_matching_color_ids(c) }
      matches
    end

    def searchable_query_items_query(query_params)
      return { query: query_params[:query] } if query_params[:query].present?
      query = query_params[:query_items] && query_params[:query_items].select { |i| !(/\A[cm]_/ =~ i) }
      query && { query: query.join(' ') } || {} # empty hash unless query is present
    end

    def searchable_query_items_manufacturer_id(query_params)
      # we expect a singular manufacturer but deal with arrays because the multi-select search
      manufacturer_id = extracted_query_items_manufacturer_id(query_params)
      if manufacturer_id && !manufacturer_id.is_a?(Integer)
        manufacturer_id = [manufacturer_id].flatten.map do |m_id|
          next m_id.to_i if m_id.is_a?(Integer) || m_id.strip =~ /\A\d*\z/
          Manufacturer.friendly_id_find(m_id)
        end.compact
        manufacturer_id = manufacturer_id.first if manufacturer_id.count == 1
      end
      manufacturer_id ? { manufacturer_id: manufacturer_id } : {}
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

    def searchable_query_stolenness(query_params, ip)
      if query_params[:stolenness] && %w(all non).include?(query_params[:stolenness])
        query_params[:stolenness] == 'non' ? { stolenness: 'non' } : {}
      else
        extracted_searchable_proximity_hash(query_params, ip) || { stolenness: 'stolen' }
      end
    end

    def extracted_query_items_manufacturer_id(query_params)
      return query_params[:manufacturer] if query_params[:manufacturer].present?
      manufacturer_id = query_params[:query_items] && query_params[:query_items].select { |i| /\Am_/ =~ i }
      return nil unless manufacturer_id && manufacturer_id.any?
      manufacturer_id.map { |i| i.gsub(/m_/, '').to_i }
    end

    def extracted_query_items_color_ids(query_params)
      return query_params[:colors] if query_params[:colors].present?
      color_ids = query_params[:query_items] && query_params[:query_items].select { |i| /\Ac_/ =~ i }
      return nil unless color_ids && color_ids.any?
      color_ids.map { |i| i.gsub(/c_/, '').to_i }
    end


    def extracted_searchable_proximity_hash(query_params, ip)
      return false unless query_params[:stolenness] == 'proximity'
      location = query_params[:location].present? && query_params[:location]
      return false unless location && !(location =~ /anywhere/i)
      distance = query_params[:distance] && query_params[:distance].to_i
      if location == 'ip' || location == 'you'
        return false unless ip.present?
        location = Geocoder.search(ip)
      end
      {
        stolenness: 'proximity',
        location:  location,
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
