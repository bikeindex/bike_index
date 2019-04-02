class BikeSearchableService
  attr_accessor :params

  SERIAL_NORMALIZED_COUNT = 3

  def initialize(params)
    @params = params
  end

  def interpreted_params(ip)
    filtered_params = {}

    filtered_params.merge(items_query)
    filtered_params.merge(items_manufacturer)
    filtered_params.merge(items_colors)
    filtered_params.merge(searchable_query_stolenness(ip))

    filtered_params
  end

  def search
    search_matching_serial.non_serial_matches
  end

  def close_serials
    return nil unless params[:serial]

    where.not(id: search.pluck(:id))
      .non_serial_matches
      .search_matching_close_serials(params[:serial])
  end

  def selected_query_items_options
    items = []

    items += [params[:query]] if params[:query].present?
    items += Manufacturer.friendly_find([params[:manufacturer]].flatten)
              .map(&:autocomplete_result_hash) if params[:manufacturer]
    items += Color.friendly_find(params[:colors])
              .map(&:autocomplete_result_hash) if params[:colors]

    items.flatten.compact
  end

  private
    def items_query
      return { query: params[:query] } if params[:query].present?

      query = params[:query_items] && params[:query_items].select { |i| !(/\A[cm]_/ =~ i) }.join(' ')
      query.present? ? { query: query } : {}
    end

    def items_manufacturer
      manufacturer_ids = extracted_query_items_manufacturer_id

      if manufacturer_ids && !manufacturer_ids.is_a?(Integer)
        manufacturer_ids = [manufacturer_ids].flatten.select { |id| id.is_a?(Integer) || id.strip =~ /\A\d*\z/ }

        manufacturer_record_ids = Manufacturer.friendly_id_find(manufacturer_ids)

        manufacturer_record_ids = manufacturer_record_ids.first if manufacturer_record_ids.length == 1
      end

      manufacturer_record_ids ? { manufacturer: manufacturer_record_ids } : {}
    end

    def items_colors
      color_ids = extracted_query_items_color_ids

      if color_ids && !color_ids.is_a?(Integer)
        color_ids = color_ids.select { |id| id.is_a?(Integer) || id.strip =~ /\A\d*\z/ }

        color_record_ids = Color.friendly_id_find(color_ids)
      end

      color_record_ids ? { colors: color_record_ids } : {}
    end

    def searchable_query_stolenness(ip)
      if params[:stolenness] && %w(all non).include?(params[:stolenness])
        { stolenness: params[:stolenness] }
      else
        extracted_searchable_proximity_hash(ip) || { stolenness: 'stolen' }
      end
    end

    def extracted_query_items_manufacturer_id
      return params[:manufacturer] if params[:manufacturer].present?
      manufacturer_id = params[:query_items] && params[:query_items].select { |i| /\Am_/ =~ i }
      return nil unless manufacturer_id && manufacturer_id.any?
      manufacturer_id.map { |i| i.gsub(/m_/, '').to_i }
    end

    def extracted_query_items_color_ids
      return params[:colors] if params[:colors].present?
      color_ids = params[:query_items] && params[:query_items].select { |i| /\Ac_/ =~ i }
      return nil unless color_ids && color_ids.any?
      color_ids.map { |i| i.gsub(/c_/, '').to_i }
    end

    def extracted_searchable_proximity_hash(ip)
      return false unless params[:stolenness] == 'proximity'

      location = params[:location]
      return false unless location && !(location =~ /anywhere/i)

      distance = params[:distance] && params[:distance].to_i
      if ['', 'ip', 'you'].include?(location.strip.downcase)
        return false unless ip.present?

        location = Geocoder.search(ip)
        if defined?(location.first.data) && location.first.data.is_a?(Array)
          location = location.first.data.reverse.compact.select { |i| i.match(/\A\D*\z/).present? }
        end
      end

      bounding_box = Geocoder::Calculations.bounding_box(location.to_s, distance)
      return false if bounding_box.detect(&:nan?)
      {
        bounding_box: bounding_box,
        stolenness: 'proximity',
        location:  location,
        distance: (distance && distance > 0) ? distance : 100
      }
    end

    def search_matching_serial
      return all_records unless params[:serial]

      Bike.where('serial_normalized @@ ?', params[:serial])
    end

    def non_serial_matches
      # We can refactor this further if I would know the complete flow and requirements of these constraints
      records = search_matching_color_ids
        .search_matching_stolenness
        .search_matching_query(params[:query])
        .where(params[:manufacturer] ? { manufacturer_id: params[:manufacturer] } : {})
    end

    def search_matching_color_ids
      return all_records unless params[:colors]

      where('primary_frame_color_id = ANY(ARRAY[:colour_ids]) OR secondary_frame_color_id = ANY(ARRAY[:colour_ids]) OR tertiary_frame_color_id = ANY(ARRAY[:colour_ids])', { colour_ids: params[:colors] })
    end

    def search_matching_stolenness
      case params[:stolenness]
        when 'all'
          all_records
        when 'non'
          where(stolen: false)
        when 'proximity'
          where(stolen: true).within_bounding_box(params[:bounding_box])
        else
          where(stolen: true)
      end
    end

    def search_matching_query(query)
      query && pg_search(query) || all_records
    end

    def search_matching_close_serials(serial)
      where('LEVENSHTEIN(serial_normalized, ?) < ?', serial, SERIAL_NORMALIZED_COUNT)
    end

    def all_records
      @all_db_records ||= Bike.all
    end
end
