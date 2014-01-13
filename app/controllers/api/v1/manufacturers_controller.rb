module Api
  module V1
    class ManufacturersController < ApiV1Controller
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers

      def index
        manufacturers = Manufacturer.all
        if params[:query]
          manufacturers = Manufacturer.fuzzy_name_find(params[:query].to_s)
        end
        respond_with manufacturers
      end

      def show
        manufacturer = Manufacturer.find_by_slug(params[:id])
        raise ActionController::RoutingError.new('Not Found') unless manufacturer.present?
        respond_with manufacturer, each_serializer: ManufacturerFullSerializer
      end
         
    end
  end
end