module API
  module V2
    class Manufacturers < API::Base
      include API::V2::Defaults

      resource :manufacturers, desc: "Accepted manufacturers" do
        desc "All the manufacturers with pagination"
        paginate
        params do
          optional :only_frame, type: Boolean, desc: "Only include Frame Manufacturers"
        end
        get "/" do
          manufacturers = params[:only_frame].present? ? Manufacturer.frame_makers : Manufacturer
          paginate manufacturers.reorder(:name)
        end

        desc "Manufacturer matching ID or name", {
          notes: <<-NOTE
            You can request a manufacturer by either their name or their ID
          NOTE
        }
        params do
          requires :id, type: String, desc: "Manufacturer id or slug"
        end
        get ":id", serializer: ManufacturerV2ShowSerializer do
          manufacturer = Manufacturer.friendly_find(params[:id])
          unless manufacturer.present?
            msg = "Unable to find manufacturer with name or id: #{params[:id]}"
            raise ActiveRecord::RecordNotFound, msg
          end
          manufacturer
        end
      end
    end
  end
end
