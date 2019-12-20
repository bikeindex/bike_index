module Api
  module V1
    class FrameMaterialsController < ApiV1Controller
      before_action :cors_preflight_check
      after_action :cors_set_access_control_headers

      def index
        respond_with FrameMaterial::NAMES
      end
    end
  end
end
