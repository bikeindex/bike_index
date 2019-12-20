module Api
  module V1
    class CycleTypesController < ApiV1Controller
      before_action :cors_preflight_check
      after_action :cors_set_access_control_headers

      def index
        respond_with CycleType::NAMES
      end
    end
  end
end
