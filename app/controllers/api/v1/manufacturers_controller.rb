module Api
  module V1
    class ManufacturersController < ApiV1Controller

      def index
        respond_with Manufacturer.all
      end

      def show
        respond_with Manufacturer.find_by_slug(params[:id])
      end
    
    end
  end
end