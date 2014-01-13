module Api
  module V1
    class WheelSizesController < ApiV1Controller
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers
      def index
        respond_with WheelSize.all
      end
    end
  end
end