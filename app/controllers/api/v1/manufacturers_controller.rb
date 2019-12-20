module Api
  module V1
    class ManufacturersController < ApiV1Controller
      before_action :cors_preflight_check
      after_action :cors_set_access_control_headers

      def index
        manufacturers = Manufacturer.reorder(:name)
        if params[:query]
          if params[:query].strip == "frame_makers"
            Manufacturer.frame_makers
          else
            manufacturers = Manufacturer.friendly_find(params[:query].to_s)
          end
        end
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
