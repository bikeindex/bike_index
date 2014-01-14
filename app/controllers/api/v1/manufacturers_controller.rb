module Api
  module V1
    class ManufacturersController < ApiV1Controller
      before_filter :cors_preflight_check
      after_filter :cors_set_access_control_headers

      def index
        manufacturers = Manufacturer.all
        if params[:query]
          if params[:query].strip == "frame_makers"
            Manufacturer.frames
          else
            manufacturers = Manufacturer.fuzzy_name_find(params[:query].to_s)
          end
        end
        respond_with manufacturers
      end

    end
  end
end