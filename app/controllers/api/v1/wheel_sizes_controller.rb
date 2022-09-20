module API
  module V1
    class WheelSizesController < APIV1Controller
      before_action :cors_preflight_check
      after_action :cors_set_access_control_headers

      def index
        respond_with WheelSize.all
      end
    end
  end
end
