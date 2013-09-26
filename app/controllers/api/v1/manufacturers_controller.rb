module Api
  module V1
    class ManufacturersController < ApiV1Controller
      def index
        manufacturers = Manufacturer.all
        if params[:callback]
          manufacturers = "#{params[:callback]}(#{manufacturers.active_model_serializer.new(manufacturers).to_json});"
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