module API
  module V1
    class ManufacturersController < APIV1Controller
      before_action :cors_preflight_check
      after_action :cors_set_access_control_headers

      def index
        if params[:query] && params[:query].strip != "frame_makers"
          return respond_with Manufacturer.friendly_find(params[:query].to_s)
        end

        manufacturers = Manufacturer.reorder(:name)
        manufacturers = manufacturers.frame_makers if params[:query]
        if params[:just_names] && manufacturers.count > 1
          respond_with manufacturers.map(&:name)
        else
          respond_with manufacturers
        end
      end

      def show
        manufacturer = Manufacturer.where(id: params[:id]).first
        respond_with manufacturer
      end
    end
  end
end
