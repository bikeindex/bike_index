module API
  module V1
    class HandlebarTypesController < APIV1Controller
      before_action :cors_preflight_check
      after_action :cors_set_access_control_headers

      def index
        respond_with HandlebarType::NAMES.transform_keys { HandlebarType.api_slug(it) }
      end
    end
  end
end
