module Api
  module V1
    class BikesController < ApiV1Controller
      before_filter :current_user, :cors_preflight_check
      after_filter :cors_set_access_control_headers

      def index
        respond_with BikeSearcher.new(params).find_bikes
      end

      def show
        respond_with Bike.find(params[:id])
      end
    end
  end
end