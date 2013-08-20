module Api
  module V1
    class ManufacturersController < ApiV1Controller

      def index
        respond_with Manufacturer.all
      end

      def show
        manufacturer = Manufacturer.find_by_slug(params[:id])
        raise ActionController::RoutingError.new('Not Found') unless manufacturer.present?
        respond_with manufacturer
      end
    
    end
  end
end