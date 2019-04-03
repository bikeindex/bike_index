class BikeSearchableService
  attr_accessor :params, :records

  SERIAL_NORMALIZED_COUNT = 3

  def initialize(params)
    @params = params
    @records = Bike.joins(:manufacturer)
  end

  def interpreted_params(ip)
    filtered_params = {}

    filtered_params = filtered_params.merge(items_query)
                                     .merge(items_manufacturer)
                                     .merge(items_colors)
                                     .merge(searchable_query_stolenness(ip))

    filtered_params
  end

  def search
    search_matching_serial
    non_serial_matches
  end

  def close_serials
    return nil if params[:serial].blank?

    records = Bike.where.not(id: search) if params[:serial].present?

    records = non_serial_matches if params[:serial].blank?

    records = search_matching_close_serials(params[:serial]) if records.present?

    records
  end

  def selected_query_items_options
    items = []

    items += [params[:query]] if params[:query].present?
    items += [params[:manufacturer]].flatten.map { |id| Manufacturer.friendly_find(id) }
             .compact.map(&:autocomplete_result_hash) if params[:manufacturer]
    items += params[:colors].map { |id| Color.friendly_find(id) }
             .compact.map(&:autocomplete_result_hash) if params[:colors]

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
        manufacturer_record_ids = [manufacturer_ids].flatten.map do |m_id|
          next m_id.to_i if m_id.is_a?(Integer) || m_id.strip =~ /\A\d*\z/

          Manufacturer.friendly_id_find(m_id)
        end.compact

        manufacturer_record_ids = manufacturer_record_ids.first if manufacturer_record_ids&.length == 1
      end

      manufacturer_record_ids ? { manufacturer: manufacturer_record_ids } : {}
    end

    def items_colors
      color_ids = extracted_query_items_color_ids

      if color_ids && !color_ids.is_a?(Integer)
        color_ids = color_ids.map do |c_id|
          next c_id.to_i if c_id.is_a?(Integer) || c_id.strip =~ /\A\d*\z/
          Color.friendly_id_find(c_id)
        end
      end

      color_ids ? { colors: color_ids } : {}
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
      return all_records if params[:serial].blank?

      records = Bike.where('serial_normalized @@ ?', params[:serial])

      records
    end

    def non_serial_matches
      records = search_matching_color_ids
      records = search_matching_stolenness if records.present? && params[:stolenness].present?
      records = search_matching_query if records.present? && params[:query].present?
      records = records.where(params[:manufacturer] ? { manufacturer_id: params[:manufacturer] } : {}) if records.present?

      records
    end

    def search_matching_color_ids
      return all_records if params[:colors].blank?

      records.where('primary_frame_color_id = ANY(ARRAY[:colour_ids]) OR secondary_frame_color_id = ANY(ARRAY[:colour_ids]) OR tertiary_frame_color_id = ANY(ARRAY[:colour_ids])', { colour_ids: params[:colors] })
    end

    def search_matching_stolenness
      case params[:stolenness]
        when 'all'
          all_records
        when 'non'
          records.where(stolen: false)
        when 'proximity'
          records.where(stolen: true).within_bounding_box(params[:bounding_box])
        else
          records.where(stolen: true)
      end
    end

    def search_matching_query
      params[:query] && records.pg_search(params[:query]) || records
    end

    def search_matching_close_serials(serial)
      records.where('LEVENSHTEIN(serial_normalized, ?) < ?', serial, SERIAL_NORMALIZED_COUNT)
    end

    def all_records
      @all_db_records ||= Bike.all
    end
end
