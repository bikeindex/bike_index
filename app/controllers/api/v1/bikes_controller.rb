module Api
  module V1
    class BikesController < ApiV1Controller

      def index
        respond_with SearchBikes.new(params).bikes
      end

      def show
        respond_with Bike.find(params[:id])
      end
    
    end
  end
end