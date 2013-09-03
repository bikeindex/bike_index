module Api
  module V1
    class WheelSizesController < ApiV1Controller
      def index
        respond_with WheelSize.all
      end
    end
  end
end