module BikeSearchable
  extend ActiveSupport::Concern
  module ClassMethods

    def searchable_interpreted_params(query_params, ip:)
      serial = SerialNormalizer.new(serial: query_params[:serial]) if query_params[:serial].present?

      bike_service = BikeSearchableService.new(query_params)

      (serial ? { serial: serial.normalized } : {})
      .merge(bike_service.interpreted_params(ip))
    end

    def search(interpreted_params)
      bike_service = BikeSearchableService.new(interpreted_params).search
    end

    def search_close_serials(interpreted_params)
      bike_service = BikeSearchableService.new(interpreted_params).close_serials
    end

    def selected_query_items_options(interpreted_params)
      bike_service = BikeSearchableService.new(interpreted_params).selected_query_items_options
    end

    def permitted_search_params
      [:query, :manufacturer, :location, :distance, :serial, :stolenness, :query_items => [], :colors => []]
    end
  end
end
