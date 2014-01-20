module Api
  module V1
    class FrameMaterialsController < ApiV1Controller
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers

      def index
        respond_with FrameMaterial.all
      end
    end
  end
end